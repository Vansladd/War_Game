# ==============================================================
# $Id: auto_letters.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::AUTO_LETTERS {
	asSetAct ADMIN::AUTO_LETTERS::DoField			[namespace code do_field]
	asSetAct ADMIN::AUTO_LETTERS::GoTemplate		[namespace code go_template]
	asSetAct ADMIN::AUTO_LETTERS::DoTemplate		[namespace code do_template]
	asSetAct ADMIN::AUTO_LETTERS::GoLetter			[namespace code go_letter]
	asSetAct ADMIN::AUTO_LETTERS::DoLetter			[namespace code do_letter]
}

proc ADMIN::AUTO_LETTERS::get_cust_letters {cust_id} {
	global DB CUST_LETTERS

	ob::log::write ERROR {ADMIN::AUTO_LETTERS::get_cust_letters}

	set stmt [inf_prep_sql $DB {
		select
			t.template_name,
			l.cr_date,
			l.last_sent,
			l.sent,
			l.letter_id
		from
			tLtrTemplate t,
			tLetter l,
			tLetterCustomer lc
		where
			lc.cust_id = ?
		and
			lc.letter_id = l.letter_id
		and
			l.template_id = t.template_id
	}]

	set res [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	tpSetVar NumLetters [set num_letters [db_get_nrows $res]]

	for {set r 0} {$r < $num_letters} {incr r} {
		set CUST_LETTERS($r,template_name)	[db_get_col $res $r template_name]
		set CUST_LETTERS($r,cr_date)		[db_get_col $res $r cr_date]
		set CUST_LETTERS($r,last_sent)		[db_get_col $res $r last_sent]
		set CUST_LETTERS($r,sent)			[db_get_col $res $r sent]
		set CUST_LETTERS($r,letter_id)		[db_get_col $res $r letter_id]
	}

	db_close $res

	tpBindVar template_name	CUST_LETTERS template_name	l_idx
	tpBindVar cr_date		CUST_LETTERS cr_date		l_idx
	tpBindVar last_sent		CUST_LETTERS last_sent		l_idx
	tpBindVar sent			CUST_LETTERS sent			l_idx
	tpBindVar letter_id		CUST_LETTERS letter_id		l_idx
}

proc ADMIN::AUTO_LETTERS::get_cust_avail_letters {cust_id} {
	global DB CUST_AVAIL_LETTERS

	ob::log::write ERROR {ADMIN::AUTO_LETTERS::get_cust_avail_letters}

	set stmt [inf_prep_sql $DB {
		select
			t.template_name,
			l.letter_id,
			l.cr_date
		from
			tLtrTemplate t,
			tLetter l
		where
			l.letter_id not in (select letter_id from tLetterCustomer where cust_id = ?)
		and
			l.template_id = t.template_id
		and
			l.sent = 'N'
		order by cr_date desc
	}]

	set res [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	tpSetVar NumLettersAvail [set num_letters [db_get_nrows $res]]

	for {set r 0} {$r < $num_letters} {incr r} {
		set CUST_AVAIL_LETTERS($r,template_name)	[db_get_col $res $r template_name]
		set CUST_AVAIL_LETTERS($r,letter_id)	[db_get_col $res $r letter_id]
		set CUST_AVAIL_LETTERS($r,cr_date)	[db_get_col $res $r cr_date]
	}

	db_close $res

	tpBindVar avail_template_name	CUST_AVAIL_LETTERS template_name	la_idx
	tpBindVar avail_letter_id		CUST_AVAIL_LETTERS letter_id		la_idx
	tpBindVar avail_cr_date		CUST_AVAIL_LETTERS cr_date		la_idx
}



proc ADMIN::AUTO_LETTERS::do_add_cust_letter args {
	
	set cust_id	[reqGetArg CustId]
	set letter_id	[reqGetArg letter_id]

	add_cust_letter $cust_id $letter_id
}



proc ADMIN::AUTO_LETTERS::add_cust_letter {cust_id letter_id} {
	global DB

	set sql {
		insert into tLetterCustomer (
			letter_id,
			cust_id
		) values (
			?,
			?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	set c [catch {
		set res [inf_exec_stmt	$stmt \
			$letter_id \
			$cust_id
		]
	} msg]

	if {$c == 0} {
		db_close $res
	} else {
		err_bind $msg
		catch {db_close $res}
		ob::log::write ERROR {add failed: $msg}
	}

	inf_close_stmt $stmt
}

proc ADMIN::AUTO_LETTERS::do_letter args {
	set submit [reqGetArg SubmitName]

	if {$submit == "AddLetter"} {
		do_add_letter
	} elseif {$submit == "SendLetter"} {
		do_send_letter
		return
	} elseif {$submit == "UpdStatus"} {
		do_update_letter_status
	} elseif {$submit == "AddCustLetter"} {
		do_add_cust_letter
		ADMIN::CUST::go_cust
		return
	}

	go_letter
}

proc ADMIN::AUTO_LETTERS::do_update_letter_status args {
	global DB

	set sent_letters [reqGetArgs sent_letters]
	set page_list [reqGetArgs page_letters]

	set page_list_length [llength $page_list]

	set sql {
		update
			tLetter
		set
			sent = ?
		where
			letter_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]

	if {$page_list_length>0} {
		for {set r 0} {$r < $page_list_length} {incr r} {

			set letter_id [lindex $page_list $r]

			if {[lsearch $sent_letters $letter_id]!=-1} {
				## is sent
				set sent_status "Y"
			} else {
				## is not sent
				set sent_status "N"
			}

			set c [catch {
				set res [inf_exec_stmt	$stmt \
					$sent_status \
					$letter_id
				]
			} msg]

			if {$c == 0} {
				db_close $res
			} else {
				err_bind $msg
				catch {db_close $res}
				ob::log::write ERROR {update failed: $msg}
			}

		}
	}

	inf_close_stmt $stmt
}

proc ADMIN::AUTO_LETTERS::generate_sql {letter_id cust_ids} {
	global DB

	## a list of the columns selected in the sql
	set columns [list]

	## a list of the tables selected in the sql
	set tables [list]

	## a list of table codes used to alias tables in the sql
	set table_codes [list]

	## a list of where clauses
	set where [list]

	## a list of columns we wish to extract to the csv
	set columns_to_get [list]

	## the column names
	set header [list]

	## the columns that require ccy formatting
	set ccy_format_cols [list]


	## a list of column names we might want to add to 'columns'
	set to_add_cn [list]

	## a list of tables we might want to add to 'tables'
	set to_add_tables [list]

	## a list of table codes we might want to add to 'table_codes'
	set to_add_tc [list]

	## a list of where clauses we might want to add to 'where'
	set to_add_where [list]

	set stmt [inf_prep_sql $DB {
		select
			f.table_code,
			f.identifier,
			tf.disp_order,
			t.template_name,
			current as today,
			f.desc
		from
			tLtrField f,
			tLtrTemplate t,
			tLtrTemplateField tf,
			tLetter l
		where
			l.letter_id = ?
		and
			l.template_id = t.template_id
		and
			t.template_id = tf.template_id
		and
			tf.field_id = f.field_id
		order by tf.disp_order
	}]

	set res [inf_exec_stmt $stmt $letter_id]
	inf_close_stmt $stmt

	set num_fields [db_get_nrows $res]
	if {$num_fields == 0} {
		return ""
	}
	set template_name [db_get_col $res 0 template_name]
	set today [db_get_col $res 0 today]

	set file_name "${template_name}_${letter_id}_${today}"
	## not using this file name right now

	for {set r 0} {$r < $num_fields} {incr r} {

		set table_code	[db_get_col $res $r table_code]
		set column	[db_get_col $res $r identifier]
		lappend header "\"[db_get_col $res $r desc]\""

		if {$table_code == "C"} {
			set table "tCustomer C"
		} elseif {$table_code == "R"} {
			set table "tCustomerReg R"
		} elseif {$table_code == "A"} {
			set table "tAcct A"
		} else {
			set table "SPECIAL"
		}

		if {$table != "SPECIAL"} {
			## we can use genric code to build up sql if column is not special
			## this table is to be selected in sql and extracted for the cvs
			## no extra, non-linkable by cust_id, tables are required

			set column_to_get "tg_$column"
			set column_name "${table_code}.${column} as $column_to_get"

			lappend columns_to_get $column_to_get
			lappend to_add_cn $column_name
			lappend to_add_tables $table
			lappend to_add_tc $table_code

		} else {
			if {$column == "COUNTRY_NAME"} {
				## special case bacuase we need to get the country code converted to its real name
				## columns to be selected for csv not all columns we will select are necessarily needed in csv, some are just needed for formating purposes
				set column_to_get "sp_country_name"
				set column_name "cntry.country_name as ${column_to_get}"

				lappend columns_to_get $column_to_get
				lappend to_add_cn $column_name
				lappend to_add_tables "tCountry cntry"
				lappend to_add_tables "tCustomer C"
				lappend to_add_tc "C"

				## where part
				lappend to_add_where "cntry.country_code == C.country_code"

			} elseif {$column == "CURRENCY_NAME"} {
				## special case bacuase we need to get the currency code converted to its real name
				## columns to be selected for csv

				set column_to_get "sp_currency_name"
				set column_name "ccy.ccy_name as ${column_to_get}"

				lappend columns_to_get $column_to_get
				lappend to_add_cn $column_name
				lappend to_add_tables "tCCY ccy"
				lappend to_add_tables "tAcct A"
				lappend to_add_tc "A"

				## where part
				lappend to_add_where "ccy.ccy_code == A.ccy_code"

			} elseif {$column == "BALANCE_FORMATTED"} {

				## we select the balance and ccy which we'll need later for formatting
				set column_to_get "tg_balance"
				set column_name "A.balance as ${column_to_get}"

				lappend columns_to_get $column_to_get
				lappend to_add_cn $column_name
				lappend to_add_cn "A.ccy_code"
				lappend to_add_tables "tAcct A"
				lappend to_add_tc "A"

				lappend ccy_format_cols "$r"

			} elseif {$column == "BALANCE_FORMATTED_NON_WTD"} {
				## we select the balance  which we'll need later for formatting
				set column_to_get "tg_balance_nowtd"
				set column_name "A.balance_nowtd as ${column_to_get}"

				lappend columns_to_get $column_to_get
				lappend to_add_cn $column_name
				lappend to_add_cn "A.ccy_code"
				lappend to_add_tables "tAcct A"
				lappend to_add_tc "A"

				lappend ccy_format_cols "$r"
			}
		}
	}

	db_close $res

	## now add the parts to the sql if necessary
	foreach cn $to_add_cn {
		if {[lsearch $columns $cn]==-1} {
			lappend columns $cn
		}
	}

	foreach tbl $to_add_tables {
		if {[lsearch $tables $tbl]==-1} {
			lappend tables $tbl
		}
	}

	foreach tc $to_add_tc {
		if {[lsearch $table_codes $tc]==-1} {
			lappend table_codes $tc
		}
	}

	foreach w $to_add_where {
		if {[lsearch $where $w]==-1} {
			lappend where $w
		}
	}

	set table_count [llength $table_codes]

	for {set n 0} {$n < [expr $table_count-1]} {incr n} {
		set this [lindex $table_codes $n]
		set that [lindex $table_codes [expr $n+1]]

		set where_part "${this}.cust_id = ${that}.cust_id"
		lappend where $where_part
	}

	## get one of the selected tables to map on to the 'in' part of the query
	set table_code [lindex $table_codes 0]

	set cust_ids "[join $cust_ids {, }]"
	lappend where "${table_code}.cust_id in (${cust_ids})"

	set where "[join $where { and }]"
	set columns "[join $columns {, }]"
	set tables "[join $tables {, }]"

	set sql [subst {
		select
			$columns
		from
			$tables
		where
			$where
	}]

	return [list $sql $columns_to_get $header $ccy_format_cols]
}

proc ADMIN::AUTO_LETTERS::do_create_letter {sql columns_to_get header ccy_format_cols} {

	if {$sql == ""} {
		tpSetVar line_count 0
		return
	}

	global FILE DB

	ob::log::write INFO {$sql}

	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]

	set header "[join $header {,}]"

	set FILE(0,line) $header

	for {set r 0} {$r < $rows} {incr r} {

		set line [list]

		for {set c 0} {$c < [llength $columns_to_get]} {incr c} {

			set column [lindex $columns_to_get $c]

			if {[lsearch $ccy_format_cols $c]!=-1} {
				## this column is a special column which needs to be currency formatted
				## we made sure earlier that ccy_code was selected and linked (via tAcct)
				set bal [db_get_col $res $r $column]
				set ccy_code [db_get_col $res $r ccy_code]
				set value [print_ccy $bal $ccy_code 0]

			} else {
				set value [db_get_col $res $r $column]
			}
			lappend line "\"${value}\""
		}
		set line "[join $line {,}]"
		set FILE([expr $r + 1],line) $line
	}

	tpSetVar line_count [expr $rows+1]
	tpBindVar line FILE line l_idx

	db_close $res
}

proc ADMIN::AUTO_LETTERS::do_send_letter args {
	global DB CHARSET

	set letter_id [reqGetArg letter_id]
	set cust_ids [list]
	set header [list]

	set stmt [inf_prep_sql $DB {
		select
			cust_id
		from
			tLetterCustomer
		where
			letter_id = ?
	}]

	set res [inf_exec_stmt $stmt $letter_id]
	inf_close_stmt $stmt

	set num_custs [db_get_nrows $res]

	if {$num_custs < 1} {
		err_bind "no customers for this letter"
		db_close $res
		return
	}

	for {set r 0} {$r < $num_custs} {incr r} {
		lappend cust_ids [db_get_col $res $r cust_id]
	}

	db_close $res

	set letter [ADMIN::AUTO_LETTERS::generate_sql $letter_id $cust_ids]

	set sql [lindex $letter 0]
	set columns_to_get [lindex $letter 1]
	set header [lindex $letter 2]
	set ccy_format_cols [lindex $letter 3]

	ADMIN::AUTO_LETTERS::do_create_letter $sql $columns_to_get $header $ccy_format_cols

	set sql {
		update
			tLetter
		set
			sent = 'Y',
			last_sent = current
		where
			letter_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]

	set c [catch {
		set res [inf_exec_stmt	$stmt \
			$letter_id
		]
	} msg]

	if {$c == 0} {
		db_close $res
	} else {
		err_bind $msg
		catch {db_close $res}
		ob::log::write ERROR {update failed: $msg}
	}

	inf_close_stmt $stmt

	tpBufAddHdr "Content-Type"  "text/csv; charset=$CHARSET"
	tpBufAddHdr "Content-Disposition" "filename=auto_letters.csv;"

	asPlayFile -nocache autoletters/file.csv

	return
}

proc ADMIN::AUTO_LETTERS::do_add_letter args {
	global DB

	set template_id [reqGetArg template_id]

	set sql {
		insert into tLetter (
			template_id
		) values (
			?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	set c [catch {
		set res [inf_exec_stmt	$stmt \
			$template_id
		]
	} msg]

	if {$c == 0} {
		db_close $res
	} else {
		err_bind $msg
		catch {db_close $res}
		ob::log::write ERROR {add failed: $msg}
	}

	inf_close_stmt $stmt
}

proc ADMIN::AUTO_LETTERS::go_letter args {
	global DB LETTERS

	set start_date	[reqGetArg start_date]
	set end_date		[reqGetArg end_date]

	if {$start_date ==""} {
		set start_date "1900-01-01 00:00:00"
	}

	if {$end_date ==""} {
		set end_date "9999-12-31 23:59:59"
	}

	tpBindString start_date $start_date
	tpBindString end_date $end_date

	set stmt [inf_prep_sql $DB {
		select
			l.letter_id,
			t.template_id,
			t.template_name,
			l.cr_date,
			l.last_sent,
			l.sent,
			count(lc.cust_id) as cust_count
		from
			tLtrTemplate t,
			tLetter l,
			outer tLetterCustomer lc
		where
			l.template_id = t.template_id
		and
			l.letter_id = lc.letter_id
		and
			cr_date >= ?
		and
			cr_date <= ?
		group by l.letter_id, t.template_id, t.template_name, l.cr_date, l.last_sent, l.sent
		order by cr_date desc
	}]

	set res [inf_exec_stmt $stmt $start_date $end_date]
	inf_close_stmt $stmt

	tpSetVar NumLetters [set NumLetters [db_get_nrows $res]]

	tpBindTcl letter_letter_id			sb_res_data $res l_idx letter_id
	tpBindTcl letter_template_id		sb_res_data $res l_idx template_id
	tpBindTcl letter_template_name		sb_res_data $res l_idx template_name
	tpBindTcl letter_cr_date			sb_res_data $res l_idx cr_date
	tpBindTcl letter_last_sent			sb_res_data $res l_idx last_sent

	for {set r 0} {$r < $NumLetters} {incr r} {
		set LETTERS($r,letter_sent)	[db_get_col $res $r sent]
		set LETTERS($r,letter_cust_count)	[db_get_col $res $r cust_count]
	}

	tpBindVar letter_sent LETTERS letter_sent l_idx
	tpBindVar letter_cust_count LETTERS letter_cust_count l_idx

	set stmt [inf_prep_sql $DB {
		select
			t.template_id,
			t.template_name
		from
			tLtrTemplate t
	}]

	set res2 [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumTemplates [db_get_nrows $res2]

	tpBindTcl template_template_id		sb_res_data $res2 tmpl_idx template_id
	tpBindTcl template_template_name	sb_res_data $res2 tmpl_idx template_name

	asPlayFile -nocache autoletters/letters.html

	db_close $res
	db_close $res2
}

proc ADMIN::AUTO_LETTERS::check_col_exists {table column} {

	global DB

	set sql "select first 1 * from $table"

	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set colnames [db_get_colnames $res]

	for {set r 0} {$r < [llength $colnames]} {incr r} {
		set from_db [lindex $colnames $r]

		if {[string tolower $from_db] == [string tolower $column]} {
			db_close $res
			return 1
		}
	}
	db_close $res

	return 0
}

proc ADMIN::AUTO_LETTERS::do_template args {

	set submit [reqGetArg SubmitName]

	if {$submit == "AddFieldTemplate"} {
		do_add_field_template
	} elseif {$submit == "DeleteField"} {
		do_delete_template_field
	} elseif {$submit == "UpdDispOrder"} {
		do_upd_field_template
	}  elseif {$submit == "ChangeName"} {
		do_change_name
	} elseif {$submit == "AddTemplate"} {
		do_add_template
		return
	} elseif {$submit == "DeleteTemplate"} {
		do_delete_template
		do_field
		return
	}

	go_template
}

proc ADMIN::AUTO_LETTERS::do_delete_template args {
	global DB

	set template_id		[reqGetArg template_id]

	set sql {
		delete from
			tLtrTemplate
		where
			template_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]

	set c [catch {
		set res [inf_exec_stmt	$stmt \
			$template_id
		]
	} msg]

	if {$c == 0} {
		db_close $res
	} else {
		err_bind $msg
		catch {db_close $res}
		ob::log::write ERROR {delete failed: $msg}
	}

	inf_close_stmt $stmt

	return
}

proc ADMIN::AUTO_LETTERS::do_add_template args {
	global DB

	set template_name	[reqGetArg template_name]

	set sql {
		insert into tLtrTemplate (
			template_name
		) values (
			?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	set c [catch {
		set res [inf_exec_stmt	$stmt \
			$template_name
		]
	} msg]

	if {$c == 0} {
		reqSetArg template_id [inf_get_serial $stmt]
		db_close $res

		go_template
	} else {
		err_bind $msg
		catch {db_close $res}
		ob::log::write ERROR {update failed: $msg}

		do_field
	}

	inf_close_stmt $stmt

	return
}

proc ADMIN::AUTO_LETTERS::do_change_name args {
	global DB

	set template_id		[reqGetArg template_id]
	set template_name	[reqGetArg template_name]

	set sql {
		update
			tLtrTemplate
		set
			template_name = ?
		where
			template_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]

	set c [catch {
		set res [inf_exec_stmt	$stmt \
			$template_name \
			$template_id
		]
	} msg]

	if {$c == 0} {
		db_close $res
	} else {
		err_bind $msg
		catch {db_close $res}
		ob::log::write ERROR {update failed: $msg}
	}

	inf_close_stmt $stmt

	return
}

proc ADMIN::AUTO_LETTERS::do_upd_field_template args {
	global DB

	set template_id	[reqGetArg template_id]
	set fields [reqGetArg used_field_count]

	set sql {
		update
			tLtrTemplateField
		set
			disp_order=?
		where
			template_id = ?
		and
			field_id = ?
		and
			disp_order = ?
	}

	set stmt [inf_prep_sql $DB $sql]

	if {$fields>0} {
		for {set r 0} {$r < $fields} {incr r} {
			set field_id [reqGetArg field_id_${r}]
			set disp_order	[reqGetArg disp_order_${r}]
			set old_disp_order	[reqGetArg old_disp_order_${r}]

			set c [catch {

			set res [inf_exec_stmt	$stmt \
					$disp_order \
					$template_id \
					$field_id \
					$old_disp_order
				]
			} msg]

			if {$c == 0} {
				db_close $res
			} else {
				err_bind $msg
				catch {db_close $res}
				ob::log::write ERROR {update failed: $msg}
			}
		}
	}

	inf_close_stmt $stmt
}

proc ADMIN::AUTO_LETTERS::do_delete_template_field args {
	global DB

	set template_id	[reqGetArg template_id]
	set field_id	[reqGetArg field_id]
	set disp_order	[reqGetArg disp_order]

	set sql {
		delete from
			tLtrTemplateField
		where
			template_id = ?
		and
			field_id = ?
		and
			disp_order = ?
	}

	set stmt [inf_prep_sql $DB $sql]

	set c [catch {
		set res [inf_exec_stmt	$stmt \
			$template_id \
			$field_id \
			$disp_order
		]
	} msg]

	if {$c == 0} {
		db_close $res
	} else {
		err_bind $msg
		catch {db_close $res}
		ob::log::write ERROR {delete failed: $msg}
	}

	inf_close_stmt $stmt

	return
}

proc ADMIN::AUTO_LETTERS::do_add_field_template args {
	global DB

	set template_id	[reqGetArg template_id]
	set field_id	[reqGetArg field_id]
	set disp_order	[reqGetArg disp_order]

	set sql {
		insert into tLtrTemplateField (
			template_id,
			field_id,
			disp_order
		) values (
			?,
			?,
			?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	set c [catch {
		set res [inf_exec_stmt	$stmt \
			$template_id \
			$field_id \
			$disp_order
		]
	} msg]

	if {$c == 0} {
		db_close $res
	} else {
		err_bind $msg
		catch {db_close $res}
		ob::log::write ERROR {Add failed: $msg}

		## rebind vars
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
	}

	inf_close_stmt $stmt
}

proc ADMIN::AUTO_LETTERS::go_template args {
	global DB

	set template_id 	[reqGetArg template_id]

	## get template
	set stmt [inf_prep_sql $DB {
		select
			t.template_id,
			t.template_name
		from
			tLtrTemplate t
		where
			t.template_id = ?
	}]
	set res [inf_exec_stmt $stmt $template_id]
	inf_close_stmt $stmt

	tpBindString template_id		[db_get_col $res 0 template_id]
	tpBindString template_name		[db_get_col $res 0 template_name]

	db_close $res

	## get used fields
	set stmt [inf_prep_sql $DB {
		select
			f.field_id,
			f.desc,
			tf.disp_order
		from
			tLtrTemplate t,
			tLtrField f,
			tLtrTemplateField tf

		where
			t.template_id = tf.template_id
		and
			tf.field_id = f.field_id
		and
			t.template_id = ?
		order by tf.disp_order
	}]
	set res [inf_exec_stmt $stmt $template_id]
	inf_close_stmt $stmt

	tpSetVar NumUsedFields [db_get_nrows $res]

	tpBindTcl used_field_id		sb_res_data $res ufld_idx field_id
	tpBindTcl used_desc			sb_res_data $res ufld_idx desc
	tpBindTcl used_disp_order	sb_res_data $res ufld_idx disp_order

	## get avaialable fields
	set stmt [inf_prep_sql $DB {
		select
			f.field_id,
			f.desc
		from
			tLtrField f
	}]

	set res2 [inf_exec_stmt $stmt $template_id]
	inf_close_stmt $stmt

	tpSetVar NumAvailFields [db_get_nrows $res2]

	tpBindTcl avail_field_id		sb_res_data $res2 afld_idx field_id
	tpBindTcl avail_desc			sb_res_data $res2 afld_idx desc

	asPlayFile -nocache autoletters/template.html

	db_close $res2
	db_close $res
}

proc ADMIN::AUTO_LETTERS::do_field args {

	set submit [reqGetArg SubmitName]

	if {$submit == "AddUpdField"} {
		do_add_upd_field
		tpBindString button_string "Add Field"
	} elseif {$submit == "ViewField"} {
		do_view_field
		tpBindString button_string "Update Field"
	} elseif {$submit == "DeleteField"} {
		do_delete_field
		tpBindString button_string "Add Field"
	} else {
		tpBindString button_string "Add Field"
	}

	go_templates_fields
}

proc ADMIN::AUTO_LETTERS::do_add_upd_field args {

	global DB

	set field_id 	[reqGetArg edit_field_id]
	set desc 		[reqGetArg edit_desc]
	set table_code 	[reqGetArg edit_table_code]
	set identifier 	[reqGetArg edit_identifier]

	set table_name ""

	if {$table_code == "C"} {
		set table_name "tCustomer"
	} elseif {$table_code == "R"} {
		set table_name "tCustomerReg"
	} elseif {$table_code == "A"} {
		set table_name "tAcct"
	}

	if {![check_col_exists $table_name $identifier]} {
		set msg "$identifier does not exits in table $table_name"
		err_bind $msg
		ob::log::write ERROR {Add failed: $msg}
		return
	}

	if {$field_id == ""} {
		## adding a fresh field

		set sql {
			insert into tLtrField (
				table_code,
				identifier,
				desc
			) values (
				?,
				?,
				?
			)
		}

		set stmt [inf_prep_sql $DB $sql]

		set c [catch {
			set res [inf_exec_stmt	$stmt \
				$table_code \
				$identifier \
				$desc
			]
		} msg]

		if {$c == 0} {
			db_close $res
		} else {
			err_bind $msg
			catch {db_close $res}
			ob::log::write ERROR {Add failed: $msg}

			## rebind vars
			for {set a 0} {$a < [reqGetNumVals]} {incr a} {
				tpBindString [reqGetNthName $a] [reqGetNthVal $a]
			}
		}

	} else {
		## editing an existing field

		set sql {
			update
				tLtrField
			set
				identifier = ?,
				desc = ?,
				table_code = ?
			where
				field_id = ?
		}

		set stmt [inf_prep_sql $DB $sql]

		set c [catch {
			set res [inf_exec_stmt	$stmt \
				$identifier \
				$desc \
				$table_code \
				$field_id
			]
		} msg]

		if {$c == 0} {
			db_close $res
		} else {
			err_bind $msg
			catch {db_close $res}
			ob::log::write ERROR {Edit failed: $msg}

			## rebind vars
			for {set a 0} {$a < [reqGetNumVals]} {incr a} {
				tpBindString [reqGetNthName $a] [reqGetNthVal $a]
			}
		}

	}

	inf_close_stmt $stmt

	return
}

proc ADMIN::AUTO_LETTERS::do_view_field args {

	global DB

	set field_id 	[reqGetArg field_id]

	set stmt [inf_prep_sql $DB {
		select
			field_id,
			table_code,
			identifier,
			desc
		from
			tLtrField
		where
			field_id =?
	}]
	set res [inf_exec_stmt $stmt $field_id]
	inf_close_stmt $stmt

	tpBindString edit_field_id		[db_get_col $res 0 field_id]
	tpBindString edit_table_code	[db_get_col $res 0 table_code]
	tpBindString edit_identifier	[db_get_col $res 0 identifier]
	tpBindString edit_desc			[db_get_col $res 0 desc]

	db_close $res

	return
}

proc ADMIN::AUTO_LETTERS::do_delete_field args {

	global DB

	set field_id 	[reqGetArg field_id]

	set sql {
		delete from
			tLtrField
		where
			field_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]

	set c [catch {
		set res [inf_exec_stmt	$stmt \
			$field_id
		]
	} msg]

	if {$c == 0} {
		db_close $res
	} else {
		err_bind $msg
		catch {db_close $res}
		ob::log::write ERROR {delete failed: $msg}
	}

	inf_close_stmt $stmt

	return
}

proc ADMIN::AUTO_LETTERS::go_templates_fields args {
	global DB FIELDS

	set ignore_field_id 	[reqGetArg field_id]

	if {$ignore_field_id == ""} {
		set ignore_field_id -1
	}

	set stmt [inf_prep_sql $DB {
		select
			template_id,
			template_name
		from
			tLtrTemplate
	}]
	set res [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumTemplates [db_get_nrows $res]

	tpBindTcl template_id	sb_res_data $res tmpl_idx template_id
	tpBindTcl template_name	sb_res_data $res tmpl_idx template_name

	set stmt [inf_prep_sql $DB {
		select
			field_id,
			decode(table_code, 'C', 'tCustomer', 'R', 'tCustomerReg', 'A', 'tAcct', 'Special')  as table_code,
			identifier,
			desc
		from
			tLtrField
		where
			field_id != ?
	}]

	set res2 [inf_exec_stmt $stmt $ignore_field_id]
	inf_close_stmt $stmt

	tpSetVar NumFields [set num_fields [db_get_nrows $res2]]

	for {set r 0} {$r < $num_fields} {incr r} {
		set FIELDS($r,table_code)	[db_get_col $res2 $r table_code]
	}

	tpBindTcl field_id		sb_res_data $res2 fld_idx field_id
	tpBindVar table_code	FIELDS table_code	fld_idx
	tpBindTcl identifier	sb_res_data $res2 fld_idx identifier
	tpBindTcl desc			sb_res_data $res2 fld_idx desc

	asPlayFile -nocache autoletters/templates_fields.html

	db_close $res
	db_close $res2
}
