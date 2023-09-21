# ==============================================================
# $Id: stmt_run.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

#
# ----------------------------------------------------------------------------
# Procedures called from here do their own transaction management
# ----------------------------------------------------------------------------
#
namespace eval ADMIN::STMTRUN {

asSetAct ADMIN::STMTRUN::GoStmtRunList     [namespace code go_stmt_run_list]
asSetAct ADMIN::STMTRUN::GoStmtRun         [namespace code go_stmt_run]
asSetAct ADMIN::STMTRUN::GoStmtReRunList   [namespace code go_stmt_rerun_list]
asSetAct ADMIN::STMTRUN::GoUploadReRunFile [namespace code go_upload_rerun_file]
asSetAct ADMIN::STMTRUN::DoUploadReRunFile [namespace code do_upload_rerun_file]


#
# Get the list of statement runs
#
proc go_stmt_run_list {} {


	global DB DATA

 	#
 	# check permissions
 	#
 	if {![op_allowed ViewStmtRun]} {
 		err_bind "You do not have permission to view statement run information"
 		asPlayFile -nocache stmt_run_list.html
 		return
	}

	if {[OT_CfgGet ELITE_STMT 0]} {
	set stmtRunSql [subst {
		select unique
			s.stmt_run_id,
			s.cr_date,
			s.stmt_run_ref,
			s.status,
			s.elite
		from
			tStmtRun s,
			outer tStmtRun o
		where
			(s.num_pull_perm +
			s.num_pull_temp +
			s.num_dep +
			s.num_dbt +
			s.num_cdt) > 0 and
			(o.num_pull_perm +
			o.num_pull_temp +
			o.num_dep +
			o.num_dbt +
			o.num_cdt) > 0 and
			o.stmt_run_id = s.stmt_run_id and
			o.elite='Y'
		order by
			s.status asc,
			s.cr_date desc
	}]

	} else {
	set stmtRunSql [subst {
		select
			stmt_run_id,
			cr_date,
			stmt_run_ref,
			status
		from
			tStmtRun
		where
			(num_pull_perm +
			num_pull_temp +
			num_dep +
			num_dbt +
			num_cdt) > 0
		order by
			status asc,
			cr_date desc
	}]
	}

	set stmtRunStmt [inf_prep_sql $DB $stmtRunSql]
	set stmtRunRes  [inf_exec_stmt $stmtRunStmt]
	inf_close_stmt $stmtRunStmt

	set numRuns    [db_get_nrows $stmtRunRes]

	#Bind stmt run data
	set DATA(numRuns) $numRuns
	set elite ""
	for {set i 0} {$i < $numRuns} {incr i} {
		set DATA($i,stmt_run_id)   [db_get_col $stmtRunRes $i stmt_run_id]
		set DATA($i,stmt_run_ref)  [db_get_col $stmtRunRes $i stmt_run_ref]
		set DATA($i,cr_date)       [db_get_col $stmtRunRes $i cr_date]
		if {[OT_CfgGet ELITE_STMT 0]} {
			set DATA($i,elite)     [db_get_col $stmtRunRes $i elite]
			set elite              [db_get_col $stmtRunRes $i elite]
		}
		if {[db_get_col $stmtRunRes $i status] == "A"} {
			set DATA($i,status) "Running"
		} else {
			set DATA($i,status) "Complete"
		}
	}
	tpBindVar StmtRunId     DATA stmt_run_id  stmt_run_idx
	tpBindVar StmtRunRef    DATA stmt_run_ref stmt_run_idx
	tpBindVar StmtRunDate   DATA cr_date      stmt_run_idx
	tpBindVar StmtRunStatus DATA status       stmt_run_idx
	if {[OT_CfgGet ELITE_STMT 0]} {
		tpBindVar StmtRunElite DATA elite     stmt_run_idx
	}

	asPlayFile -nocache stmt_run_list.html

	db_close $stmtRunRes
	catch {unset DATA}
}

proc go_stmt_run {} {

	global DB DATA

  	#
  	# check permissions
  	#
  	if {![op_allowed ViewStmtRun]} {
  		err_bind "You do not have permission to view statement run information"
  		asPlayFile -nocache stmt_run_list.html
  		return
 	}

	set elite [reqGetArg Elite]
	if {$elite == ""} {
		set elite "N"
	}

	#
	# Retrieve the info on the stmt run
	#
	tb_statement_build::get_stmt_run_report [reqGetArg StmtRunId] IN $elite


	#
	# Create array with the data, so we can just loop from the template
	#
	set index 0

	#
	# Chuck in some translations
	#
	set DATA(numTypes) 6
	set DATA(dep) "Deposit"
	set DATA(cdt) "Credit"
	set DATA(dbt) "Debit"
	set DATA(pull_temp) "Temp Pulled"
	set DATA(pull_perm) "Perm Pulled"

	set done_total 0
	set num_total  0

	# Work out a rough predicted finish time
	regexp {^(....)-(..)-(..) (..):(..):(..)$} $IN(cr_date) all yr mn dy hh mm ss
	set start [clock scan "$mn/$dy/$yr $hh:$mm:$ss"]
	set now   [clock seconds]
	set factor 0

	foreach type [list dep cdt dbt pull_temp pull_perm] {

		#Type data
		set DATA($index,name)       $DATA($type)
		set DATA($index,num)        $IN(num_$type)
		set DATA($index,done)       $IN(done_$type)
		if {$IN(num_$type) == 0} {
			set DATA($index,done_width) 100
		} else {
			set DATA($index,done_width) [expr ceil((100 * $IN(done_$type)) / $IN(num_$type))]
		}
		set DATA($index,num_width)  [expr 100 - $DATA($index,done_width)]

		#Totals
		incr done_total $IN(done_$type)
		incr num_total  $IN(num_$type)

		#End time - default to 1 printed if none have been
		set safedone 1
		if {$IN(done_$type) > 1} {set safedone $IN(done_$type)}
		set temp_factor [expr {($IN(num_$type) - $safedone) / $safedone}]
		if {$temp_factor > $factor} {set factor $temp_factor}


		#Counter
		incr index
	}
	set DATA($index,name)       "Total"
	set DATA($index,num)        $num_total
	set DATA($index,done)       $done_total
	if {$num_total == 0} {
		set DATA($index,done_width) 100
	} else {
		set DATA($index,done_width) [expr ceil((100 * $done_total) / $num_total)]
	}
	set DATA($index,num_width)  [expr 100 - $DATA($index,done_width)]


	tpBindVar Name      DATA name       type_idx
	tpBindVar Num       DATA num        type_idx
	tpBindVar Done      DATA done       type_idx
	tpBindVar TodoWidth DATA num_width  type_idx
	tpBindVar DoneWidth DATA done_width type_idx

	if {$elite == "Y"} {
		tpBindString EliteStmt 1
	} else {
		tpBindString EliteStmt 0
	}
	tpBindString StmtRunId   $IN(stmt_run_id)
	tpBindString StmtRunRef  $IN(stmt_run_ref)
	tpBindString StmtRunDate $IN(cr_date)
	tpBindString NumFailed   $IN(num_failed)


	if {$IN(status) == "A"} {
		set endscan [format %.0f [expr {ceil($now + (($now - $start) * $factor))}]]
		tpBindString Status "Running"
		tpBindString EndTime [clock format $endscan -format "%H:%M:%S"]
	} else {
		tpBindString Status "Complete"
		tpBindString EndTime "n/a"
	}

	asPlayFile -nocache stmt_run.html

	catch {unset DATA}
}

# Display the upload screen stmt_rerun_upload.html for re running stmts
# stmt_rerun_upload.html runs UPLOAD_CGI scgi script to upload the file
# from the specified directory
proc go_stmt_rerun_list {} {
	global FILE

	set UPLOAD_DIR [OT_CfgGet UPLOAD_DIR]
	set UPLOAD_URL [OT_CfgGet UPLOAD_URL]

	tpBindString UPLOAD_URL $UPLOAD_URL

	set months [list "" Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec]

	set mrx {([12][09][0-9][0-9])-([01][0-9])-([0-3][0-9])}
	set trx {([012][0-9]):([0-5][0-9]):([0-5][0-9])}
	set drx ${mrx}_${trx}\$


	set type "statements"
	set files [glob -nocomplain $UPLOAD_DIR/$type/*]
	set n_files 0
	foreach f $files {
		set ftail [file tail $f]
		if [regexp $drx $ftail time y m d hh mm ss] {
			if [regsub _$drx $ftail "" ftrunc] {
				set m [lindex $months [string trimleft $m 0]]
				set FILE($n_files,type)     $type
				set FILE($n_files,date)     "$y-$m-$d $hh:$mm:$ss"
				set FILE($n_files,fullname) [urlencode $ftail]
				set FILE($n_files,trunc)    [html_encode $ftrunc]
				set FILE($n_files,time)     $time
	  			incr n_files
			}
		}
	}
	tpSetVar NumFiles $n_files
	tpBindVar FileType FILE type     file_idx
	tpBindVar FileTime FILE date     file_idx
	tpBindVar FileName FILE trunc    file_idx
	tpBindVar FileKey  FILE fullname file_idx

	asPlayFile -nocache upload/stmt_rerun_upload.html
}

# read a CSV file into global FILE array
# executed on selection of a uploaded file in the 'Uploaded Files' section
# and call stmt_rerun_upload_file.html to show the contents
# and allow 'Run Statements','Delete File' and 'Back' buttons
proc go_upload_rerun_file {} {

	global FILE

	set UPLOAD_DIR [OT_CfgGet UPLOAD_DIR]

	set type [reqGetArg FileType]
	set name [reqGetArg FullName]

	set f [open $UPLOAD_DIR/$type/$name r]

	if {[gets $f line] <= 0} {
		close $f
		error "file is empty"
	}

	set mrx {([12][09][0-9][0-9])-([01][0-9])-([0-3][0-9])}
	set trx {([012][0-9]):([0-5][0-9]):([0-5][0-9])}
	set drx ${mrx}_${trx}\$

	regsub _$drx $name "" plain_name

	tpBindString FileType [html_encode $type]
	tpBindString FullName [html_encode $name]
	tpBindString FileName [html_encode $plain_name]

	set ok 1

	set header [csv_split $line]

	#
	# Check the file header - if it's not ok, we take an early bath...
	#
	if {[ADMIN::UPLOAD::upload_val_line $type $header 1]} {
		set ncols [llength $header]
		for {set c 0} {$c < $ncols} {incr c} {
			set FILE($c,HEADER) [lindex $header $c]
		}
		set FILE(HEADER,OK) 1

		tpSetVar HeaderOK 1
	} else {
		tpSetVar     HeaderOK   0
		tpSetVar     FileOK     0
		tpBindString NumCols    1
		tpBindString HeaderLine $line

		asPlayFile -nocache upload/stmt_rerun_upload_file.html

		catch {unset FILE}
		return
	}

	set ok       1
	set line_num 0

	#
	# Check each line of the file
	#
	while {[gets $f line] >= 0} {

		#
		# Trim amy leading or trailing crud
		#
		set line [string trim $line]

		set data [csv_split $line]

		if {[ADMIN::UPLOAD::upload_val_line $type $data]} {
			set ncols [llength $data]
			for {set c 0} {$c < $ncols} {incr c} {
				set FILE($line_num,$c,DATA) [lindex $data $c]
			}
			set FILE($line_num,OK) 1
		} else {
			set FILE($line_num,DATA) $line
			set FILE($line_num,OK) 0
			set ok 0
		}

		incr line_num
	}

	close $f

	tpSetVar     NumLines     $line_num
	tpSetVar     NumCols      [llength $header]
	tpBindString NumCols      [llength $header]
	tpBindString NumColsPlus1 [expr {1+[llength $header]}]
	tpBindString do_pmt_only  [reqGetArg do_pmt_only]

	tpBindVar FileHeader FILE HEADER col_idx
	tpBindVar FileData   FILE DATA   line_idx col_idx
	tpBindVar BadData    FILE DATA   line_idx

	tpSetVar FileOK $ok

	asPlayFile -nocache upload/stmt_rerun_upload_file.html

	catch {unset FILE}
}


# With a uploaded file displayed, process (Run Statements), delete the file
# or cancel.
proc do_upload_rerun_file {} {
	set op [reqGetArg SubmitName]

	if {$op == "RunStatements"} {
		#Upload the contents of the file, and process
		do_upload_load
	} elseif {$op == "FileDel"} {
		do_upload_delete
		go_stmt_rerun_list
	} elseif {$op == "Back"} {
		go_stmt_rerun_list
	} else {
		error "unexpected operation : $op"
	}
}

# Upload the statements file, and recreate the last 'Run' statement for each
# customer defined by the account number
proc do_upload_load args {

	global DB USERNAME FILE USERID

	set type [reqGetArg FileType]
	set name [reqGetArg FullName]

	set mrx {([0-3][0-9])[-/]([01][0-9])[-/]([12][09][0-9][0-9])}
	set trx {([012][0-9]):([0-5][0-9])}
	set drx "$mrx $trx\$"
	#Read CSV file into global var FILE
	if {![ADMIN::UPLOAD::do_upload_load_file $type $name]} {
		error "failed to load $type file $name"
	}

	set fields [ADMIN::UPLOAD::get_upload_fields $type]

	set bad 0

	set line_num 0

	if {[catch {
			#Loop for num rows
			tpSetVar NumAccounts $FILE(NUM_LINES)
		for {set l 0} {$l < $FILE(NUM_LINES)} {incr l} {
			set line_num $l

			#
			# build up the arguments
			#
			#loop for num cols - thisis not needed inthis version.
			for {set i 0; set j 0} {$i < [llength $fields]} {} {

				#
				# generate the argument(s)
				#
				set f_spec    [lindex $fields $i]
				set f_type    [lindex $f_spec 0]
				set f_name    [lindex $f_spec 1]
				set f_special [lindex $f_spec 2]

				#
				# see if we're copying from another column
				#
				set col [locate_field $f_name]
				if {$col == -1} {
					set al_data ""
				} else {
					set al_data [string trim $FILE($l,$col,DATA)]
				}

				#Generate most recent statement for account number $al_data!
				set stmt_id [get_stmt_id $al_data]
				generate_statement $al_data $stmt_id $l

				incr i
				incr j
			}

		}
		asPlayFile -nocache stmt_reruns.html

	} msg]} {
		set bad 1
		err_bind $msg
		tpSetVar UploadFailed 1
		tpBindString ErrLine [expr {$line_num+1}]
	} else {
		tpSetVar UploadOK 1
	}

	catch {unset FILE}
}

proc locate_field {field} {

	global FILE

	for {set i 0} {$i < $FILE(HEADER,NUM_COLS)} {incr i} {
		if {$FILE($i,HEADER) == $field} {
			return $i
		}
	}
	return -1
}

# Delete the passed file from the filesystem
proc do_upload_delete args {

	set UPLOAD_DIR [OT_CfgGet UPLOAD_DIR]

	set type [reqGetArg FileType]
	set name [reqGetArg FullName]

	if {[catch {
		file delete $UPLOAD_DIR/$type/$name
	} msg]} {
		error "failed to delete $UPLOAD_DIR/$type/$name"
	}
}

# Execute a query to get the stmt_id for the relative acc_id (Customer
# Account Id for their last 'Run' statement
# The query assumes only 1 account per customer
proc get_stmt_id {acc_id} {
	global DB

	set c [catch {
	#Get the stmt_id
	set sql {
		select
			first 1 stmt_id
		from
			tCustomer c,
			tAcct a,
			tStmtrecord s
		where
			c.acct_no= ? and
			c.cust_id=a.cust_id and
			a.acct_id=s.acct_id and
			s.sort='R'
		order by s.stmt_id desc}

	set stmt [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $stmt $acc_id]
	if {[db_get_nrows $rs] > 0} {
		set stmt_id [db_get_col $rs 0 stmt_id]
	} else {
		OT_LogWrite 2 "Statement ReRun - Account $acc_id invalid"
		set stmt_id -1
		msg_bind "Some account id's invalid check the server log"
	}
	inf_close_stmt $stmt
	} msg]
	if {$c} {
		msg_bind "Statement retrieval error: $msg"
		set stmt_id -1
	}

	return $stmt_id
}

# Regenerate the customer statement associated with 'stmt_id' for the customer
# account 'acc_id'
proc generate_statement {acc_id stmt_id loop} {
	global ARR

	if {$stmt_id == -1} {
		set ARR($loop,acc_num) $acc_id
		set ARR($loop,file_name) "No statement generated"
		tpBindVar hacc_num ARR acc_num rridx
		tpBindVar hfile_name ARR file_name rridx
		return
	}
	array set DATA ""
	tb_statement_build::get_stmt_data $stmt_id DATA

	set stmt_dir [OT_CfgGet STATEMENT_DIR]
	set filename "$DATA(hdr,acct_type)-$DATA(hdr,due_to)-$DATA(hdr,acct_no).csv"
	regsub -all { } $filename {-} filename
	set path "$stmt_dir/$filename"
	set ARR($loop,acc_num) $acc_id
	set ARR($loop,file_name) $path
	tpBindVar hacc_num ARR acc_num rridx
	tpBindVar hfile_name ARR file_name rridx

	#
	# open the file (for statement generation)
	#
	set f_id [open "$path" w]
	fconfigure $f_id -encoding [OT_CfgGet STATEMENTS_CHARSET iso8859-1]

	#
	# If we are writing a postscript statement then we want to write
	# the postscript functions to the top of the file first
	#
	if {[OT_CfgGet POSTSCRIPT_STMTS 0]} {
		::tb_statement_build::init_ps_output $f_id 1
	}
	
	#
	# write the data
	#
	tb_statement_build::write_stmt_to_file $f_id DATA

	#
	# If using postscript we need to add a final command to the bottom
	#
	if {[OT_CfgGet POSTSCRIPT_STMTS 0]} {
		puts $f_id "showpage"
	}

	close $f_id

}

}

