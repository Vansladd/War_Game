#-------------------------------------------------------------------------------
# Copyright (C) 2005 Orbis Technology Ltd.  All rights reserved.
#-------------------------------------------------------------------------------
# $Id: cust_notices.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#-------------------------------------------------------------------------------

namespace eval ADMIN::CUST::NOTICE {

	asSetAct ADMIN::CUST::NOTICE::add    [namespace code add]
	asSetAct ADMIN::CUST::NOTICE::show   [namespace code show]
	asSetAct ADMIN::CUST::NOTICE::delete [namespace code delete]

}


proc ADMIN::CUST::NOTICE::bind cust_id {

	global DB NOTICES

	set stmt [inf_prep_sql $DB {

		select
			cr_date,
			ntc_id,
			from_date,
			to_date,
			ntc_type,
			xl_code as title,
			body_id,
			read,
			date_read,
			deleted,
			date_deleted
		from tCustNotice
		where cust_id = ?
		order by cr_date

	}]

	set ok 1

	if { [catch {
		set rs [inf_exec_stmt $stmt $cust_id]
	} err] } {

		OT_LogWrite 1 "ADMIN::CUST::NOTICE::bind:\
			query failed for cust_id #$cust_id: $err"

		err_bind "ADMIN::CUST::NOTICE::bind:\
			query failed for cust_id #$cust_id: $err"

		set ok 0

	}

	inf_close_stmt $stmt

	if { !$ok } {
		return
	}

	tpSetVar NumNtcs [set nrows [db_get_nrows $rs]]

	set columns [db_get_colnames $rs]

	for {set i 0} {$i < $nrows} {incr i} {

		foreach col $columns {
			set NOTICES($i,$col) [db_get_col $rs $i $col]
		}

		if { $NOTICES($i,ntc_type) eq "B" } {

			foreach {
				code_id lang xl
			} [_get_xlation $NOTICES($i,title)] break

			if { $xl ne "" } {
				set NOTICES($i,title) $xl
			}

		} else {

			foreach {
				title
				body
			} [_get_body $NOTICES($i,body_id)] break

			set NOTICES($i,title) $title

		}

	}

	db_close $rs

	foreach col $columns {
		tpBindVar NTC_$col NOTICES $col i
	}

}


proc ADMIN::CUST::NOTICE::show {} {

	set ntc_id [reqGetArg ntc_id]

	if { $ntc_id ne "" } {
		_show_details $ntc_id
	} else {
		_show_form
	}

}


proc ADMIN::CUST::NOTICE::add {} {

	set cust_id   [reqGetArg cust_id]
	set lang      [reqGetArg lang]
	set title     [reqGetArg title]
	set body      [reqGetArg body]
	set from_date [reqGetArg from_date]
	set to_date   [reqGetArg to_date]

	set stmt [inf_prep_sql $::DB {

		execute procedure pInsCustNotice (
			p_adminuser = ?,
			p_cust_id   = ?,
			p_title     = ?,
			p_body      = ?,
			p_from_date = ?,
			p_to_date   = ?
		);

	}]

	set ok 1

	if { [catch {
		set rs [inf_exec_stmt -inc-type $stmt \
			$::USERNAME STRING                \
			$cust_id    STRING                \
			$title      STRING                \
			$body       TEXT                  \
			$from_date  STRING                \
			$to_date    STRING                \
		]
	} err] } {

		err_bind "Could not add message: $err"

		OT_LogWrite 1 "ADMIN::CUST::NOTICE::add: query failed: $err"

		set ok 0

	}

	inf_close_stmt $stmt

	if { $ok } {

		set ntc_id [db_get_coln $rs 0]

		db_close $rs

		_show_details $ntc_id

	} else {

		tpBindString title     $title
		tpBindString body      $body
		tpBindString from_date $from_date
		tpBindString to_date   $to_date

		_show_form

	}

}


proc ADMIN::CUST::NOTICE::delete {} {

	set ntc_id [reqGetArg ntc_id]

	set stmt [inf_prep_sql $::DB {

		update tCustNotice set
			deleted      = 'Y',
			date_deleted = current,
			user_id      = ?
		where
			ntc_id = ?;

	}]

	if { [catch {
		inf_exec_stmt $stmt $::USERID $ntc_id
	} err] } {

		err_bind "Could not delete message: $err"

		OT_LogWrite 1 "ADMIN::CUST::NOTICE::delete:\
			query failed for ntc_id #$ntc_id: $err"

	} else {
		msg_bind "Message Deleted"
	}

	inf_close_stmt $stmt

	ADMIN::CUST::go_cust

}


proc ADMIN::CUST::NOTICE::_get_xlation code {

	set results [list]

	set rs [ADMIN::MSG::ml_exact_search_codes $code]

	if { $rs eq "" } {
		return $results
	}

	set code_id [db_get_col $rs code_id]

	db_close $rs

	lappend results $code_id

	#
	# Display in English, if a translation exists, the first available
	# lang, otherwise.
	#
	set rs [ADMIN::MSG::ml_get_xlated_langs $code_id]

	if { $rs ne "" } {

		set n [db_get_nrows $rs]

		if { $n } {

			set lang [db_get_col $rs lang]

			for { set i 0 } { $i < $n } { incr i } {

				if { [db_get_col $rs $i lang] eq "en" } {
					set lang en
					break
				}

			}

		} else {
			set lang en
		}

		db_close $rs

		lappend results $lang

		lappend results [ADMIN::MSG::ml_get_xlation $code_id $lang]

	}

	return $results

}


proc ADMIN::CUST::NOTICE::_get_body body_id {

	set stmt [inf_prep_sql $::DB {

		select
			title,
			body
		from tCustNtcBody
		where body_id = ?;

	}]

	if { [catch {
		set rs [inf_exec_stmt $stmt $body_id]
	} err] } {

		err_bind "ADMIN::CUST::NOTICE::_get_body:\
			query failed for #$body_id: $err"
		OT_LogWrite 1 "ADMIN::CUST::NOTICE::_get_body:\
			query failed for #$body_id: $err"

		return [list "" ""]

	}

	inf_close_stmt $stmt

	if { ![db_get_nrows $rs] } {
		return [list "" ""]
	}

	set results [list [db_get_col $rs title] \
					  [db_get_col $rs  body] ]

	db_close $rs

	return $results

}


proc ADMIN::CUST::NOTICE::_show_details ntc_id {

	tpBindString ntc_id $ntc_id

	set stmt [inf_prep_sql $::DB {

		select
			cust_id,
			from_date,
			to_date,
			ntc_type,
			xl_code,
			body_id,
			read,
			date_read,
			deleted,
			date_deleted
		from tCustNotice
		where ntc_id = ?;

	}]

	if { [catch {
		set rs [inf_exec_stmt $stmt $ntc_id]
	} err] } {

		err_bind "ADMIN::CUST::NOTICE::_show_details:\
			query failed for message #$ntc_id: $err"

		OT_LogWrite 1 "ADMIN::CUST::NOTICE::_show_details:\
			query failed for #$ntc_id: $err"

		asPlayFile -nocache cust_notice_details.html

		return

	}

	inf_close_stmt $stmt

	if { ![db_get_nrows $rs] } {

		err_bind "could not find message."
		db_close $rs
		asPlayFile -nocache cust_notice_details.html
		return

	}

	foreach col {
		cust_id
		from_date
		to_date
		read
		date_read
		deleted
		date_deleted
	} {
		tpBindString $col [db_get_col $rs $col]
	}

	foreach col {
		ntc_type
		xl_code
		body_id
	} {
		set $col [db_get_col $rs $col]
	}

	db_close $rs

	tpBindString ntc_type $ntc_type

	if { $ntc_type eq "B" } {

		foreach {
			binding code
		} [list \
			title   ${xl_code}      \
			body    ${xl_code}_BODY \
		] {

			if { $rs ne "" } {

				foreach {
					code_id
					lang
					xl
				} [_get_xlation $code] break

				tpBindString ${binding}_id      $code_id
				tpBindString ${binding}_lang    $lang
				tpBindString ${binding}_xlation $xl

			}

		}

	} else {

		foreach {
			title
			body
		} [_get_body $body_id] break

		tpBindString title $title
		tpBindString body  $body

	}

	asPlayFile -nocache cust_notice_details.html

}


proc ADMIN::CUST::NOTICE::_show_form {} {

	tpBindString cust_id [reqGetArg cust_id]

	asPlayFile -nocache cust_notice_form.html

}

#-------------------------------------------------------------------------------
# vim:noet:ts=4:sts=4:sw=4:tw=80:ft=tcl:ff=unix:
#-------------------------------------------------------------------------------
