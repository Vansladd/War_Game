# Copyright (c) 2003 Orbis Technology Limited. All rights reserved.
# ==============================================================
# $Id: msg.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
# ==============================================================
#
# Notes:
#    Currently only works with charset = utf-8.
#
#

namespace eval ADMIN::MSG {

asSetAct ADMIN::MSG::go_ml_msg    [namespace code go_ml_msg]
asSetAct ADMIN::MSG::go_codes     [namespace code go_codes]
asSetAct ADMIN::MSG::add_code     [namespace code add_code]
asSetAct ADMIN::MSG::delete_codes [namespace code delete_codes]
asSetAct ADMIN::MSG::move_codes   [namespace code move_codes]
asSetAct ADMIN::MSG::go_val       [namespace code go_val]
asSetAct ADMIN::MSG::update_val   [namespace code update_val]
asSetAct ADMIN::MSG::do_search    [namespace code do_search]

#
# Action Handler for messages page
#
#
proc go_ml_msg args {
	global DB

	global GROUPS

	catch {unset GROUPS}

	set sql [subst {select distinct group from tXlateCode order by group}]
	set stmt [inf_prep_sql $DB $sql]
	if {[catch {set rs [inf_exec_stmt $stmt]} msg]} {
		OT_LogWrite 2 "Could not get groups: $msg"
		inf_close_stmt $stmt
		error "Could not get groups: $msg"
	}
	inf_close_stmt $stmt
	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		set group [db_get_col $rs $i group]
		set GROUPS($i,group) $group
		set GROUPS($i,group_enc) [html_encode $group]
	}

	tpSetVar num_groups $i

	tpBindVar group     GROUPS group     group_idx
	tpBindVar group_enc GROUPS group_enc group_idx

	db_close $rs

	asPlayFile -nocache "msg_sel.html"
}

#
# Action handler to play message codes iframe.
#
# Request Args:
#   group   - Which group to show codes from, or ALL for all codes.
#           - If left blank, or an unknown group specified page IS still played (but with no codes)
#
proc go_codes {} {

	global DB

	global CODES LANG_AVAIL LANGS

	catch {unset CODES LANG_AVAIL LANGS}

	set group [reqGetArg group]

	OT_LogWrite 5 "Getting codes for group $group"

	set sql [subst {
		select
			c.code_id,
			c.code,
			v.lang
		from
			tXlateCode c,
			outer tXlateVal v
		where
		    c.code_id = v.code_id
	}]
	if {$group != "ALL"} {
		append sql "and group = ?"
	}
	append sql " order by c.code"

	set bad 0
	set stmt [inf_prep_sql $DB $sql]
	if {[catch {set rs [inf_exec_stmt $stmt $group]} msg]} {
		OT_LogWrite 2 "Could not get codes for group '$group' : $msg"
		err_bind "Could not get codes for group '$group' : $msg"
		set bad 1
	}
	inf_close_stmt $stmt

	if {!$bad} {
		set nrows [db_get_nrows $rs]
		set code_idx 0
		for {set i 0} {$i < $nrows} {incr i} {
			foreach v {code_id code lang} {
				set $v [db_get_col $rs $i $v]
			}
			if {$code_idx == 0 || $CODES([expr {$code_idx - 1}],code_id) != $code_id} {
				set CODES($code_idx,code_id) $code_id
				set CODES($code_idx,code) $code
				incr code_idx
			}
			if {$lang != ""} {
				set LANG_AVAIL($code_id,$lang) 1
			}
		}

		tpSetVar num_codes $code_idx
		tpBindVar code    CODES code    code_idx
		tpBindVar code_id CODES code_id code_idx

		db_close $rs
	} else {
		tpSetVar num_codes 0
	}

	tpBindString group [reqGetArg group]
	tpBindString group_enc [html_encode [reqGetArg group]]

	tpBindString scroll_to_code_id [reqGetArg scroll_to_code_id]

	bind_langs
	asPlayFile -nocache "msg_codes.html"

}

#
# Action handler to add a new code to a group
#
# Request Args:
#   group    -
#   code     -
#
proc add_code {{code ""} {group ""} {play_file 1}} {

	global DB

	if {$code == ""} {
		set code [reqGetArg code]
	}
	if {$group == ""} {
		set group [reqGetArg group]
	}

	OT_LogWrite 5 "Adding code '$code' to group $group"

	set sql  [subst "insert into tXlateCode (code, group) values (?,?)"]
	set stmt [inf_prep_sql $DB $sql]
	if {[catch {inf_exec_stmt $stmt $code $group} msg]} {
		if {[string first "-268" $msg] != -1} {
			err_bind "Code '$code' already exists"
		} else {
			OT_LogWrite 2 "Could not add code '$code': $msg"
			err_bind "Could not add code '$code': $msg"
		}
	} else {
		set code_id [inf_get_serial $stmt]
		OT_LogWrite 5 "Added code with id $code_id"
		reqSetArg code_id $code_id
		tpBindString auto_show_code 1
		reqSetArg scroll_to_code_id $code_id
	}
	inf_close_stmt $stmt

	if {$play_file} {
		go_codes
	}
}

#
# Action handler to deleted selected codes
#
# Request Args:
#   group    -
#   code_id  -
#
proc delete_codes {} {

	set code_ids [reqGetArgs code_id]

	if { ![llength $code_ids] } {
		go_codes
		return
	}

	global DB

	OT_LogWrite 5 "Deleting codes $code_ids"

	set ok 1

	set st [inf_prep_sql $DB [subst {

		delete from tXlateVal
		where code_id in
			(
			[join $code_ids ",\n\t\t\t"]
			);

	}]]

	if {[catch {
		inf_exec_stmt $st
	} msg]} {
		OT_LogWrite 2 "Could not delete translations for codes $code_ids: $msg"
		err_bind "Could not delete translations for codes $code_ids: $msg"
		set ok 0
	}

	inf_close_stmt $st

	if { $ok } {

		set st [inf_prep_sql $DB [subst {

			delete from tXlateCode
			where code_id in
				(
				[join $code_ids ",\n\t\t\t\t"]
				);

		}]]

		if {[catch {
			inf_exec_stmt $st
		} msg]} {
			OT_LogWrite 2 "Could not delete codes $code_ids: $msg"
			err_bind "Could not delete codes $code_ids: $msg"
		}

		inf_close_stmt $st

	}

	go_codes

}

#
# Action handler to move selected codes to another group
#
# Request Args:
#   to_group -
#   code_id  -
#
proc move_codes {} {
	global DB

	set code_ids [reqGetArgs code_id]
	set to_group [reqGetArg to_group]

	OT_LogWrite 1 "Moving codes $code_ids to group $to_group"

	set sql "update tXlateCode set group = ? where code_id in ([join $code_ids ,])"
	set stmt [inf_prep_sql $DB $sql]
	if {[catch {inf_exec_stmt $stmt $to_group} msg]} {
		OT_LogWrite 2 "Could not move codes $code_ids to group '$to_group': $msg"
		err_bind "Could not move codes $code_ids to group '$to_group': $msg"
	}
	inf_close_stmt $stmt

	reqSetArg group $to_group
	go_codes
}

#
# Action handler to play translation iframe.
#
# Request Args:
#   code_id -
#   lang    -
#
proc go_val {} {

	global DB LANG_VAL

	set code_id  [reqGetArg code_id]
    set code_val [reqGetArg code_val]
	set lang     [reqGetArg lang]

	if {$code_id != ""} {
		OT_LogWrite 1 "Retrieving $lang translation for code $code_id"
		set sql {
			select
				c.code,
				c.group,
				l.name as lang_desc
			from
				tXlateCode c,
				tLang l
			where c.code_id = ?
			  and l.lang = ?
		}
		set db_param $code_id
	} else {
		OT_LogWrite 1 "Retrieving $lang translation for code $code_val"
		set sql {
			select
				c.code,
				c.group,
				l.name as lang_desc
			from
				tXlateCode c,
				tLang l
			where c.code = ?
			  and l.lang = ?
		}
		set db_param $code_val
	}
	OT_LogWrite 1 $sql
	set stmt [inf_prep_sql $DB $sql]
	if {[catch {set rs [inf_exec_stmt $stmt $db_param $lang]} msg]} {
		OT_LogWrite 2 "Could not get info for code $code_id and lang $lang : $msg"
		inf_close_stmt $stmt
		err_bind "Could not get info for code $code_id and lang $lang : $msg"
		asPlayFile -nocache "msg_val.html"
		return
	}
	inf_close_stmt $stmt

	if {[db_get_nrows $rs] != 1} {
		OT_LogWrite 2 "Info query for code $code_id and lang $lang returned wrong number of rows"
		db_close $rs
		err_bind "Info query for code $code_id and lang $lang returned wrong number of rows"
		asPlayFile -nocache "msg_val.html"
		return
	}

	set code [db_get_col $rs 0 code]
	set group [db_get_col $rs 0 group]
	set lang_desc [db_get_col $rs 0 lang_desc]
	db_close $rs

	set sql [subst {
		select
			xlation_1,
			xlation_2,
			xlation_3,
			xlation_4
		from
			tXlateVal v
		where
			v.code_id = ? and v.lang = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {set rs [inf_exec_stmt $stmt $code_id $lang]} msg]} {
		OT_LogWrite 2 "Could not get translation for code $code_id and lang $lang : $msg"
		inf_close_stmt $stmt
		err_bind "Could not get translation for code $code_id and lang $lang : $msg"
		asPlayFile -nocache "msg_val.html"
		return
	}
	inf_close_stmt $stmt

	if {[db_get_nrows $rs] == 0} {
		set xlation ""
	} elseif {[db_get_nrows $rs] == 1} {
		set xlation [concat [db_get_col $rs 0 xlation_1][db_get_col $rs 0 xlation_2][db_get_col $rs 0 xlation_3][db_get_col $rs 0 xlation_4]]
	} else {
		OT_LogWrite 2 "Translation query for code $code_id and lang $lang returned more than one row"
		db_close $rs
		err_bind "Translation query for code $code_id and lang $lang returned more than one row"
		asPlayFile -nocache "msg_val.html"
		return
	}

	db_close $rs

	tpBindString group $group
	tpBindString code_id $code_id
	tpBindString code $code
	tpBindString lang $lang
	tpSetVar lang $lang
	tpBindString lang_desc $lang_desc
	tpBindString xlation $xlation

	bind_langs_single_code $code_id

	asPlayFile -nocache "msg_val.html"
}

#
# Action handler to add translation.
#
# Request Args:
#   code_id -
#   lang    -
#   xlation -
#
proc update_val {} {

	global DB LANG_VAL

	foreach v {group code_id code lang lang_desc xlation} {
		set $v [reqGetArg $v]
		tpBindString $v [set $v]
	}

	OT_LogWrite 1 "Updating $lang translation for code '$code'"

	# Check for funnies
	# -allow Office String.format place holders {\d+}
	if {[regexp {[][{}\\]} [regsub -all {{\d+}} $xlation {}]]} {
		err_bind "Your input contains invalid characters"
		asPlayFile -nocache "msg_val.html"
		return
	}

	if {$xlation == ""} {

		set stmt [inf_prep_sql $DB {

			delete from tXlateVal
			where code_id = ?
			  and lang    = ?

		}]

		if {[catch {inf_exec_stmt $stmt $code_id $lang} msg]} {
			err_bind "Could not update $lang translation for $code: $msg"
		} else {
			tpBindString status_msg "Translation deleted."
			tpSetVar do_group_update 1
		}

		inf_close_stmt $stmt

	} else {

		tpSetVar do_group_update 0

		set st [inf_prep_sql $DB {

			execute procedure pInsXlation (
				p_group   = ?,
				p_code    = ?,
				p_lang    = ?,
				p_xlation = ?
			);

		}]

		set st_split [inf_prep_sql $DB {

			execute procedure pInsXlation (
				p_group   = ?,
				p_code    = ?,
				p_lang    = ?,
				p_xlation_1 = ?,
				p_xlation_2 = ?,
				p_xlation_3 = ?,
				p_xlation_4 = ?,
				p_use_split_xlation = 'Y'
			);
		}]

		if {[OT_CfgGet MSG_USE_SPLIT_XLATIONS 0] && [OT_CfgGet ISO_DB 1]} {

			set xlation_list [_get_divided_string $xlation 255]
    		set xlation_1 [lindex $xlation_list 0]
    		set xlation_2 [lindex $xlation_list 1]
    		set xlation_3 [lindex $xlation_list 2]
    		set xlation_4 [lindex $xlation_list 3]

			if { [catch {
				set rs [inf_exec_stmt $st_split $group $code $lang $xlation_1 $xlation_2 $xlation_3 $xlation_4]
			} msg] } {
				inf_close_stmt $st_split
				err_bind "Could not insert $lang translation for $code: $msg"
			} else {
				tpBindString status_msg "Translation inserted."
				tpSetVar do_group_update 1
			}

		} else {

			if { [catch {
				set rs [inf_exec_stmt $st $group $code $lang $xlation]
			} msg] } {
				inf_close_stmt $st
				err_bind "Could not insert $lang translation for $code: $msg"
			} else {
				tpBindString status_msg "Translation inserted."
				tpSetVar do_group_update 1
			}
		}

		set code_id [db_get_coln $rs 0]

		db_close $rs

	}

	tpSetVar lang $lang

	bind_langs_single_code $code_id
	OT_LogWrite 1 "~~~~~~~~~~~~~~~ $code_id"
	asPlayFile -nocache "msg_val.html"
}

#
# Bind up languages
#
proc bind_langs {{prefix ""}} {
	global DB LANGS

	set sql {
		select lang, name, disporder from tLang order by disporder
	}

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {set rs [inf_exec_stmt $stmt]} msg]} {
		OT_LogWrite 2 "Could not get languages : $msg"
		inf_close_stmt $stmt
		return ""
	}
	inf_close_stmt $stmt

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		set LANGS($i,lang) [db_get_col $rs $i lang]
		set LANGS($i,lang_name) [db_get_col $rs $i name]
	}
	db_close $rs

	tpBindVar lang      LANGS lang      lang_idx
	tpBindVar lang_name LANGS lang_name lang_idx

	tpSetVar num_langs $i
	tpBindString num_langs $i
}

proc bind_langs_single_code code_id {

	global DB LANG_VAL

    array unset LANG_VAL

	set stmt [inf_prep_sql $DB {

		select
			l.disporder,
			l.lang,
			(   select
					count (*)
				from tXlateVal
				where code_id = ?
				  and lang    = l.lang
				) as defined
		from
			tLang l
        order by l.disporder

	}]

	set rs [inf_exec_stmt $stmt $code_id]

	inf_close_stmt $stmt

	for {set i 0; set n [db_get_nrows $rs]} {$i < $n} {incr i} {

		set LANG_VAL($i,lang)    [db_get_col $rs $i lang]
		set LANG_VAL($i,defined) [db_get_col $rs $i defined]

	}

	db_close $rs

	tpSetVar num_langs $n

	tpBindVar lang_val     LANG_VAL lang lang_idx
	tpBindVar lang_defined LANG_VAL defined lang_idx

}

proc do_search {} {
	global DB RESULTS

	catch {unset RESULTS}

	tpSetVar num_results 0

	foreach v {search_category search_type search_text search_case_sensitive} {
		set $v [reqGetArg $v]
	}

	OT_LogWrite 2 "Doing $search_category $search_type,\
				   case_sensitive $search_case_sensitive search\
				   (text=$search_text)"

	if {$search_category == "" || $search_type == "" || $search_text == ""} {
		asPlayFile -nocache "msg_results.html"
		return
	}

	set max_results 500

	if {$search_category == "Codes"} {
		set sql [subst {
			select
				c.code_id,
				c.code,
				c.group,
				v.xlation_1 as trans
			from
				tXlateCode c,
				outer tXlateVal v
			where c.code_id = v.code_id
			  and v.lang    = ?
			  and [expr { $search_case_sensitive == "on"
							? "       code  like        ?"
							: "upper (code) like upper (?)" }]
			order by group, code
		}]
		set lang "en"
	} else {
		set sql [subst {
			select
				c.code_id,
				c.code,
				c.group,
				v.xlation_1 as trans
			from
				tXlateCode c,
				tXlateVal  v
			where c.code_id = v.code_id
			  and v.lang    = ?
			  and [expr { $search_case_sensitive == "on"
							? "       v.xlation_1  like        ?"
							: "upper (v.xlation_1) like upper (?)" }]
			order by group, code
		}]
		set lang $search_category
	}

	regsub "%" $search_text "\\%" search_text

	if {$search_type == "Containing"} {
		set search_text "%${search_text}%"
	}  else {
		set search_text "${search_text}%"
	}

	OT_LogWrite 10 "using search_text $search_text lang=$lang"

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {set rs [inf_exec_stmt $stmt $lang $search_text]} msg]} {
		OT_LogWrite 2 "Could not perform search : $msg"
		inf_close_stmt $stmt
		err_bind "Could not perform search : $msg"
		asPlayFile -nocache "msg_results.html"
		return
	}
	inf_close_stmt $stmt

	set truncation_limit 30
	tpBindString truncation_limit $truncation_limit

	for {set i 0} {$i < [db_get_nrows $rs] && $i < $max_results} {incr i} {
		set RESULTS($i,group)   [db_get_col $rs $i group]
		set RESULTS($i,code_id) [db_get_col $rs $i code_id]
		set RESULTS($i,code)    [db_get_col $rs $i code]
		set trans [db_get_col $rs $i trans]
		if {[string length $trans] > $truncation_limit} {
			set trans_result "[string range $trans 0 $truncation_limit]..."
		} else {
			set trans_result $trans
		}
		set RESULTS($i,trans) $trans_result
	}
	db_close $rs

	tpSetVar num_results $i

	tpBindVar group RESULTS group result_idx
	tpBindVar code RESULTS code result_idx
	tpBindVar code_id RESULTS code_id result_idx
	tpBindVar trans RESULTS trans result_idx

	if {$i == $max_results} {
		tpBindString status_msg "Too many matches; first $max_results results shown:"
	} else {
		tpBindString status_msg "$i matches found:"
	}
	asPlayFile -nocache "msg_results.html"
}
}

#
# get xlation for a given language and code_id
#
proc ADMIN::MSG::ml_get_xlation {code_id lang} {

	global DB

	set sql [subst {
		select xlation_1,
			   xlation_2,
			   xlation_3,
			   xlation_4
		from   tXlateVal
		where  code_id=?
		and    lang=?
	}]

	set stmt [inf_prep_sql $DB $sql]
	if [catch {set rs [inf_exec_stmt $stmt $code_id $lang]} msg] {
		OT_LogWrite 2 "get_xlation query failed for $code_id $lang : $msg"
		inf_close_stmt $stmt
		return ""
	 } else {
		inf_close_stmt $stmt
		if {[db_get_nrows $rs]<1} {
			db_close $rs
			return ""
		} else {
			set xlation [db_get_col $rs 0 xlation_1]
			append xlation [db_get_col $rs 0 xlation_2]
			append xlation [db_get_col $rs 0 xlation_3]
			append xlation [db_get_col $rs 0 xlation_4]
			db_close $rs
			return $xlation
		}
	}
}

proc ADMIN::MSG::ml_get_xlated_langs {code_id} {

	global DB
	set sql [subst {
		select xv.lang, disporder
		from   tXlateVal xv,tLang ln
		where  xv.lang=ln.lang
		and  xv.code_id = ?
		order by disporder
	}]

	set stmt [inf_prep_sql $DB $sql]
	if [catch {set rs [inf_exec_stmt $stmt $code_id]} msg] {
		OT_LogWrite 2 "get_xlated_langs query failed : $msg"
		err_bind "Failed to get languages : $msg"
		inf_close_stmt $stmt
		return ""
	}
	inf_close_stmt $stmt

	return $rs
}

proc ADMIN::MSG::ml_exact_search_codes {code} {

	global DB
	set sql [subst {
		select code_id,
			   code,
		   group
		from   tXlateCode
		where  code = ?
		order by code
	}]
	set stmt [inf_prep_sql $DB $sql]
	if [catch {set rs [inf_exec_stmt $stmt $code]} msg] {
		OT_LogWrite 2 "search_codes query failed : $msg"
		err_bind "Search failed : $msg"
		inf_close_stmt $stmt
		return ""
	}
	inf_close_stmt $stmt

	if {[db_get_nrows $rs]<1} {
		OT_LogWrite 2 "search_codes : no rows found"
		err_bind "No matches found"
		return ""
	} else {
		return $rs
	}
}


# Determine the appropriate break points for the string and return them as a list
# Collength is the length of the db column in bytes.
# This will only work for dbs that are iso - this shouldn't be necessary for others.
proc ADMIN::MSG::_get_divided_string {xlation collength} {
	# First, determine the encoding
	# If the encoding is utf-8, then
	set tcl_encoding [encoding system]
	OT_LogWrite 5 "xlation: $xlation"
	# We "take the string down" until it safely fits into the db as utf-8 per row
	# on a char-by-char basis (as opposed to byte-by-byte).

	# We need to reduce the string character-by-character until its
	# bytelength is less than the required size.
	set xlation [encoding convertfrom utf-8 $xlation]
	set xlation_list [list]
	while {$xlation != ""} {
		set new_xlation $xlation
		# Reduce the new_xlation to the size required
		for {set new_xlation $xlation} {[string bytelength $new_xlation] > $collength} {set new_xlation [string range $new_xlation 0 end-1]} {}
		lappend xlation_list $new_xlation
		# cut off that part of the translation from the translation string itself
		set xlation [string range $xlation [string length $new_xlation] end]
	}

	# Finally, we need to ensure we're returning the string in an appropriate format
	for {set i 0} {$i < [llength $xlation_list]} {incr i} {
		set xlation_list [lreplace $xlation_list $i $i [encoding convertto utf-8 [lindex $xlation_list $i]]]
	}

	# Return the list
	return $xlation_list
}


