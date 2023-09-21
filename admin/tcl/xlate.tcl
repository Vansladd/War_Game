# $Id: xlate.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $

namespace eval ADMIN::XLATE {

	asSetAct ADMIN::XLATE::go_xlate    [namespace code {go_xlate}]

	asSetAct ADMIN::XLATE::get_langs   [namespace code {get_langs}]

	asSetAct ADMIN::XLATE::get_codes   [namespace code {get_codes}]
	asSetAct ADMIN::XLATE::ins_code    [namespace code {
		ins_code [reqGetArg group] [reqGetArg code]}]

	asSetAct ADMIN::XLATE::get_xlations [namespace code {
		get_xlations [reqGetArg code_id]}]
	asSetAct ADMIN::XLATE::find_xlation [namespace code {
		find_xlation [reqGetArg xlation]}]
	asSetAct ADMIN::XLATE::ins_xlation [namespace code {
		ins_xlation [reqGetArg code_id] [reqGetArg lang] [reqGetArg xlation]}]

}

proc ADMIN::XLATE::get_translation {lang key} {
	global DB

	set sql {
		select x.xlation_1,
			x.xlation_2,
			x.xlation_3,
			x.xlation_4
		from   tXlateCode c, tXlateVal x
		where  c.code_id = x.code_id
		and    c.code = ?
		and    x.lang = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $key $lang]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	if {$nrows == 0} {
		set message $key
	} else {
		set message "[db_get_col $res 0 xlation_1][db_get_col $res 0 xlation_2][db_get_col $res 0 xlation_3][db_get_col $res 0 xlation_4]"
	}

	ob::log::write INFO {get_translation lang: $lang key: $key returned: $message}
	return $message
}


# Show the interactive translations interactive.
#
proc ADMIN::XLATE::go_xlate {} {

	if {![op_allowed ManageMessages]} {
		error "You do not have permission to do this"
	}

	asPlayFile -nocache xlate/xlate.html
}



# A utility procedure to make getting result sets easier.
#
#   sql        - an SQL statement
#   prefix     - a prefix to be put before each of the bind sites, ususally one
#                or two characters followed by an underscore, e.g. E_ EN_
#   array_name - the name of a global array that the data will be bound into
#
proc ADMIN::XLATE::_bind_sql {sql prefix array_name} {

	upvar #0 $array_name DATA

	array unset DATA

	set stmt [inf_prep_sql $::DB $sql]
	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]
	set colnames [db_get_colnames $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		foreach n $colnames {
			set DATA($r,$n) [db_get_col $rs $r $n]
		}
	}

	db_close $rs

	OT_LogWrite 4 "Selected $nrows rows into $array_name"

	set DATA(nrows) $nrows

	foreach n $colnames {
		tpBindVar ${prefix}$n $array_name $n ${prefix}idx
	}

	tpSetVar ${prefix}nrows $nrows

}



# RPC call to get the languages, also bind a translation if a code is supplied.
#
proc ADMIN::XLATE::get_langs {} {

	set sql [subst {
		select lang, name from tLang order by name
	}]

	_bind_sql $sql L_ LANGS

	tpSetVar action get_langs

	asPlayFile -nocache xlate/rpc.html
}



# RPC call for codes.
#
#   group - group to get
#
proc ADMIN::XLATE::get_codes {} {

	set sql [subst {
		select group, code_id, code from tXlateCode order by group, code
	}]

	_bind_sql $sql C_ CODES

	tpSetVar action get_codes

	asPlayFile -nocache xlate/rpc.html

}



# RPC call to insert a new code.
#
#   group - group
#   code  - code
#
proc ADMIN::XLATE::ins_code {group code} {

	set sql [subst {
		insert into tXlateCode(group, code) values (?, ?)
	}]

	set stmt [inf_prep_sql $::DB $sql]
	set caught [catch {
		inf_exec_stmt $stmt $group $code
		tpBindString group   $group
		tpBindString code_id [inf_get_serial $stmt]
		tpBindString code    $code
	} msg]
	inf_close_stmt $stmt

	if {!$caught} {
		set msg "Inserted code"
	}

	tpBindString msg $msg
	tpSetVar is_error $caught

	tpSetVar action ins_code

	asPlayFile -nocache xlate/rpc.html
}



# RPC call to find translation.
#
#   xlation - translation
#
proc ADMIN::XLATE::find_xlation {xlation} {

	set sql [subst {
		select
			c.group,
			c.code_id,
			c.code,
			v.lang,
			v.xlation_1,
			v.xlation_2,
			v.xlation_3,
			v.xlation_4
		from
			tXlateCode c,
			tXlateVal v
		where
			c.code_id   = v.code_id
		and v.xlation_1 like '$xlation%'
		order by
			c.group, c.code, v.lang
	}]

	_bind_sql $sql X_ XLATIONS

	tpSetVar action find_xlation

	asPlayFile -nocache xlate/rpc.html
}



# RPC call to get xlations.
#
#   code_id - code id
#
proc ADMIN::XLATE::get_xlations {code_id} {

	set sql [subst {
		select
			lang,
			xlation_1,
			xlation_2,
			xlation_3,
			xlation_4
		from
			tXlateVal
		where
			code_id = $code_id
	}]

	_bind_sql $sql X_ XLATIONS

	tpSetVar action get_xlations

	asPlayFile -nocache xlate/rpc.html
}



# RPC call to insert a new translation
#
#   code_id - translation code id
#   lang    - language
#   xlation - translation
#
proc ADMIN::XLATE::ins_xlation {code_id lang xlation} {

	if {![op_allowed ManageMessages]} {
		error "You do not have permission to do this"
	}

	if {[catch {
		_ins_xlation $code_id $lang $xlation
	} msg]} {
		tpBindString msg $msg
		tpSetVar is_error 1
	} else {
		tpBindString msg "Translation updated"
		tpSetVar is_error 0

		tpBindString lang $lang
		tpBindString xlation $xlation
	}

	tpSetVar action ins_xlation

	asPlayFile -nocache xlate/rpc.html
}



# Insert a new translation.
#
#   code_id - translation code id
#   lang    - language
#   xlation - translation
#
proc ADMIN::XLATE::_ins_xlation {code_id lang xlation} {

	if {![op_allowed ManageMessages]} {
		error "You do not have permission to do this"
	}

    # split xlation
	set is_iso_db [OT_CfgGet ISO_DB 1]
	if {$is_iso_db} {
		set xlation_list [_get_divided_string $xlation 255]
    	set xlation_1 [lindex $xlation_list 0]
    	set xlation_2 [lindex $xlation_list 1]
    	set xlation_3 [lindex $xlation_list 2]
    	set xlation_4 [lindex $xlation_list 3]
	}

    set sql [subst {
        insert into tXlateVal (
			code_id, lang, xlation_1, xlation_2, xlation_3, xlation_4
		) values (
			?, ?, ?, ?, ?, ?
		)
	}]

	set stmt [inf_prep_sql $::DB $sql]
	set caught [catch {
		set rs [inf_exec_stmt $stmt $code_id $lang $xlation_1 $xlation_2 \
			$xlation_3 $xlation_4]
	} msg]
	inf_close_stmt $stmt

	if {$caught && [string match "*Unique constraint*" $msg]} {
		set sql [subst {
			update
				tXlateVal
			set
				xlation_1   = ?,
				xlation_2   = ?,
				xlation_3   = ?,
				xlation_4   = ?
				[expr {
					[OT_CfgGet MLANG_USE_LAST_UPDATED 0] ?
					{, last_update=current} : {}}]
			where
				code_id = ?
			and lang    = ?
		}]

		set stmt [inf_prep_sql $::DB $sql]
		set caught [catch {
			set rs [inf_exec_stmt $stmt $xlation_1 $xlation_2 \
				$xlation_3 $xlation_4 $code_id $lang]
		} msg]
		inf_close_stmt $stmt
	}

	if {$caught} {
		error $msg $::errorInfo $::errorCode
	}
}

# Determine the appropriate break points for the string and return them as a list
# Collength is the length of the db column in bytes.
# This will only work for dbs that are iso - this shouldn't be necessary for others.
proc ADMIN::XLATE::_get_divided_string {xlation collength} {
	# First, determine the encoding
	# If the encoding is utf-8, then
	set tcl_encoding [encoding system]
	OT_LogWrite 5 "xlation: $xlation"
	# We "take the string down" until it safely fits into the db as utf-8 per row
	# on a char-by-char basis (as opposed to byte-by-byte).

	# First convertto identity, then convertfrom utf-8 so we can be sure it's in utf-8.
	# Once in UTF-8 we need to reduce the string character-by-character until its
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