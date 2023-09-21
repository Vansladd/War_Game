# ==============================================================
# $Id: oncourse.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================


namespace eval ADMIN::ONCOURSE {
	asSetAct ADMIN::ONCOURSE::GoOnCourseCust  [namespace code go_oncourse_cust]
	asSetAct ADMIN::ONCOURSE::GoOnCourseTrans [namespace code go_oncourse_trans]
	asSetAct ADMIN::ONCOURSE::GoOnCourse      [namespace code go_oncourse]
	asSetAct ADMIN::ONCOURSE::DoOnCourse      [namespace code do_oncourse]

	variable OC_DATA
	variable OC_FORMATS
	variable punter_sql
	set punter_sql {
		select unique
			c.acct_no,
			r.title,
			r.fname,
			r.mname,
			r.lname
		from
			tOnCourseCust oc,
			tCustomer c,
			tCustomerReg r
		where
			oc.acct_no     =  c.acct_no and
			c.status       = 'A' and
			c.cust_id not in (
				select
					c.cust_id
				from
					tCustomer c,
					tCustStatusFlag s
				where
					c.cust_id = s.cust_id and
					s.status_flag_tag  in ('DEBTST2', 'DEBTST3','DEBTST4') and
					s.status = 'A'
			) and
			r.cust_id      =  c.cust_id
	}
}



proc ADMIN::ONCOURSE::_define_OC_FORMATS {} {
	variable OC_FORMATS
	variable punter_sql

	set signed_int_pat {^[-+]?\d+$}
	set fractional_pat {^\d+/\d+$}
	set short_time_pat {^\d\d?:\d\d?$}
	set time_pat       {^\d\d?:\d\d?:\d\d?$}
	set date_pat       {^\d\d?/\d\d?/\d\d?$}

	set OC_FORMATS(row_type_list) [list M R H B C]

	set OC_FORMATS(M,column_list) [list date rep_code win_stakes \
	                                    pl_stakes win_ret pl_ret cash_start \
	                                    cash_book_ret cash_rec_paid cash_at_fin \
                                        cash_transfer cash_adj actual_cash]
	set OC_FORMATS(R,column_list) [list meeting_key win_stakes pl_stakes \
	                                    win_ret pl_ret cash_win_stakes \
	                                    cash_pl_stakes credit_win_stakes \
	                                    credit_pl_stakes office_hedge_stakes \
	                                    crs_hedge_stakes office_hedge_ret \
	                                    crs_hedge_ret res_settled reason_not_stld \
	                                    settled_time rule4 race_time]
	set OC_FORMATS(H,column_list) [list race_key runner_name odds position \
	                                    win_ret pl_ret]
	set OC_FORMATS(B,column_list) [list race_key runner_key account_num \
	                                    trans_type ratio_bet to_win each_way \
	                                    fair_price hedged price win_stake \
	                                    place_stake win_ret pl_ret rule4 void_bet \
	                                    void_time ticket_prod ticket_id date time \
	                                    paid_out]
	set OC_FORMATS(C,column_list) [list  acct_num meeting_key rep_code cash \
	                                     pmt_type cheq_num bank_acct_num]

	set OC_FORMATS(M,key_col)   "meeting"
	set OC_FORMATS(R,key_col)   "race"
	set OC_FORMATS(H,key_col)   "runner"
	set OC_FORMATS(B,key_col)   "bet"
	set OC_FORMATS(C,key_col)   "cheq"

	# list is of the format: [list col_desc   col_num   pattern]
	set OC_FORMATS(M,format_list,meeting)       [list "Meeting Key"       1   ""]
	set OC_FORMATS(M,format_list,date)          [list "Date"              2   $date_pat]
	set OC_FORMATS(M,format_list,rep_code)      [list "Rep Code"          3   ""]
	set OC_FORMATS(M,format_list,win_stakes)    [list "Win Stakes"        6   $signed_int_pat]
	set OC_FORMATS(M,format_list,pl_stakes)     [list "Place Stakes"      7   $signed_int_pat]
	set OC_FORMATS(M,format_list,win_ret)       [list "Win W/L"           8   $signed_int_pat]
	set OC_FORMATS(M,format_list,pl_ret)        [list "Place W/L"         9   $signed_int_pat]
	set OC_FORMATS(M,format_list,cash_start)    [list "Cash at Start"    13   $signed_int_pat]
	set OC_FORMATS(M,format_list,cash_book_ret) [list "Cash Book W/L"    14   $signed_int_pat]
	set OC_FORMATS(M,format_list,cash_rec_paid) [list "Cash Rec Paid"    15   $signed_int_pat]
	set OC_FORMATS(M,format_list,cash_at_fin)   [list "Cash at Finish"   21   $signed_int_pat]
	set OC_FORMATS(M,format_list,cash_transfer) [list "Cash Transfer"    22   $signed_int_pat]
	set OC_FORMATS(M,format_list,cash_adj)      [list "Cash Adjustment"  23   $signed_int_pat]
	set OC_FORMATS(M,format_list,actual_cash)   [list "Actual Cash"      24   $signed_int_pat]

	set OC_FORMATS(R,format_list,race)                  [list  "Race Key"                  1  ""]
	set OC_FORMATS(R,format_list,meeting_key)           [list  "Meeting Key"               2  ""]
	set OC_FORMATS(R,format_list,win_stakes)            [list  "Win Stakes"                3  $signed_int_pat]
	set OC_FORMATS(R,format_list,pl_stakes)             [list  "Place Stakes"              4  $signed_int_pat]
	set OC_FORMATS(R,format_list,win_ret)               [list  "Win W/L"                   5  $signed_int_pat]
	set OC_FORMATS(R,format_list,pl_ret)                [list  "Place W/L"                 6  $signed_int_pat]
	set OC_FORMATS(R,format_list,cash_win_stakes)       [list  "Cash Win Stakes"           7  $signed_int_pat]
	set OC_FORMATS(R,format_list,cash_pl_stakes)        [list  "Cash Place Stakes"         8  $signed_int_pat]
	set OC_FORMATS(R,format_list,credit_win_stakes)     [list  "Credit Win Stakes"         9  $signed_int_pat]
	set OC_FORMATS(R,format_list,credit_pl_stakes)      [list  "Office Hedge Stakes"      10  $signed_int_pat]
	set OC_FORMATS(R,format_list,office_hedge_stakes)   [list  "Crs Hedge Stakes"         11  $signed_int_pat]
	set OC_FORMATS(R,format_list,crs_hedge_stakes)      [list  "Office Hedge Stakes"      12  $signed_int_pat]
	set OC_FORMATS(R,format_list,office_hedge_ret)      [list  "Office Hedge W/L"         13  $signed_int_pat]
	set OC_FORMATS(R,format_list,crs_hedge_ret)         [list  "Crs Hedge W/L"            14  $signed_int_pat]
	set OC_FORMATS(R,format_list,res_settled)           [list  "Result Settled"           16  ""]
	set OC_FORMATS(R,format_list,reason_not_stld)       [list  "Reason for not Settling"  17  ""]
	set OC_FORMATS(R,format_list,settled_time)          [list  "Result Time"              18  $time_pat]
	set OC_FORMATS(R,format_list,rule4)                 [list  "Rule 4"                   20  ""]
	set OC_FORMATS(R,format_list,race_time)             [list  "Race Time"                25  $short_time_pat]


	set OC_FORMATS(H,format_list,runner)         [list  "Runner Key"   1   ""]
	set OC_FORMATS(H,format_list,race_key)       [list  "Race Key"     2   ""]
	set OC_FORMATS(H,format_list,runner_name)    [list  "Runner Name"  3   ""]
	set OC_FORMATS(H,format_list,odds)           [list  "Odds"         5   ""]
	set OC_FORMATS(H,format_list,position)       [list  "Position"     6   ""]
	set OC_FORMATS(H,format_list,win_ret)        [list  "Win W/L"      7   $signed_int_pat]
	set OC_FORMATS(H,format_list,pl_ret)         [list  "Place W/L"    8   $signed_int_pat]

	set OC_FORMATS(B,format_list,bet)          [list  "Bet Key"             1  ""]
	set OC_FORMATS(B,format_list,race_key)     [list  "Race Key"            2  ""]
	set OC_FORMATS(B,format_list,runner_key)   [list  "Runner Key"          3  ""]
	set OC_FORMATS(B,format_list,account_num)  [list  "Account Num"         4  ""]
	set OC_FORMATS(B,format_list,trans_type)   [list  "Trans Type"          8  ""]
	set OC_FORMATS(B,format_list,ratio_bet)    [list  "Ratio Bet"           9  ""]
	set OC_FORMATS(B,format_list,to_win)       [list  "Cover to Win"       10  ""]
	set OC_FORMATS(B,format_list,each_way)     [list  "Cover to Each Way"  11  ""]
	set OC_FORMATS(B,format_list,fair_price)   [list  "Fair Price"         12  ""]
	set OC_FORMATS(B,format_list,hedged)       [list  "Hedged Bet"         13  ""]
	set OC_FORMATS(B,format_list,price)        [list  "Price"              14  $fractional_pat]
	set OC_FORMATS(B,format_list,win_stake)    [list  "Win Stake"          15  $signed_int_pat]
	set OC_FORMATS(B,format_list,place_stake)  [list  "Place Stake"        16  $signed_int_pat]
	set OC_FORMATS(B,format_list,win_ret)      [list  "Win Returns"        17  $signed_int_pat]
	set OC_FORMATS(B,format_list,pl_ret)       [list  "Place Returns"      18  $signed_int_pat]
	set OC_FORMATS(B,format_list,rule4)        [list  "Rule4"              21  ""]
	set OC_FORMATS(B,format_list,void_bet)     [list  "Void Bet"           22  ""]
	set OC_FORMATS(B,format_list,void_time)    [list  "Void Time"          23  ""]
	set OC_FORMATS(B,format_list,ticket_prod)  [list  "Ticket Prod"        24  ""]
	set OC_FORMATS(B,format_list,ticket_id)    [list  "Ticket ID"          25  ""]
	set OC_FORMATS(B,format_list,date)         [list  "Date"               26  $date_pat]
	set OC_FORMATS(B,format_list,time)         [list  "Time"               27  $time_pat]
	set OC_FORMATS(B,format_list,paid_out)     [list  "Paid Out"           28  ""]

	# cheq rows do not have a unique identifier, so we set that column to -1
	set OC_FORMATS(C,format_list,cheq)          [list  "Cash/Cheque Trans Num"  -1  ""]
	set OC_FORMATS(C,format_list,acct_num)      [list  "Account Number"          1  ""]
	set OC_FORMATS(C,format_list,meeting_key)   [list  "Meeting Key"             3  ""]
	set OC_FORMATS(C,format_list,rep_code)      [list  "Rep Code"                4  ""]
	set OC_FORMATS(C,format_list,cash)          [list  "Cash Amount"             5  $signed_int_pat]
	set OC_FORMATS(C,format_list,pmt_type)      [list  "Payment Type"            6  ""]
	set OC_FORMATS(C,format_list,cheq_num)      [list  "Cheque Number"           7  ""]
	set OC_FORMATS(C,format_list,bank_acct_num) [list  "Bank Acct Number"        8  ""]

}



# creates a csv file in the OB manual bets format.
# returns location of that file.
proc ADMIN::ONCOURSE::go_oncourse {} {
	set type [reqGetArg "type"]
	switch -- $type {
		cust {
			go_oncourse_cust
		}
		trans {
			go_oncourse_trans
		}
		default {
			ob_log::write ERROR {go_oncourse: Unrecognised type $type}
		}
	}
}



proc ADMIN::ONCOURSE::go_oncourse_cust {} {
	global DB
	global OC_PUNTERS
	variable punter_sql

	# bind stuff for Download of punters
	tpBindString DownloadPunterPath [OT_CfgGet ONCOURSE_DIR]

	# retrieve and bind OC_PUNTERS
	set stmt [inf_prep_sql $DB $punter_sql]
	set res  [inf_exec_stmt  $stmt]
	inf_close_stmt $stmt

	set numRows [db_get_nrows $res]
	for {set i 0} {$i < $numRows} {incr i} {
		set OC_PUNTERS($i,title)       [regsub -all -- {,} [db_get_col $res $i title] ""]
		set OC_PUNTERS($i,finit)       [regsub -all -- {,} [string range [db_get_col $res $i fname] 0 0] ""]
		set OC_PUNTERS($i,minit)       [regsub -all -- {,} [string range [db_get_col $res $i mname] 0 0] ""]
		set OC_PUNTERS($i,lname)       [regsub -all -- {,} [db_get_col $res $i lname] ""]
		set OC_PUNTERS($i,acct_no)     [db_get_col $res $i acct_no]
	}
	db_close $res

	tpSetVar  numPunters  $numRows
	tpBindVar CustTitle   OC_PUNTERS title     punterIndex
	tpBindVar CustFInit   OC_PUNTERS finit     punterIndex
	tpBindVar CustMInit   OC_PUNTERS minit     punterIndex
	tpBindVar CustLName   OC_PUNTERS lname     punterIndex
	tpBindVar CustAcctNo  OC_PUNTERS acct_no   punterIndex
	# End of Punters section

	asPlayFile -nocache  oncourse/oncourse_cust.html
}



proc ADMIN::ONCOURSE::go_oncourse_trans {} {
	global DB
	global OC_BATCH
	global OC_FILES
	global OC_MEETINGS

	# retrieve and bind OC_BATCH
	set sql {
		select
			ocb.ocb_id,
			ocb.course,
			ocb.meeting_date,
			mb.batch_ref_id,
			b.cr_date
		from
			tOnCourseBatch ocb,
			outer (tOCMeetingBatches mb, tBatchReference b)
		where
			ocb.ocb_id = mb.ocb_id and
			mb.batch_ref_id = b.batch_ref_id
		order by ocb.meeting_date, ocb.course
	}
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt  $stmt]
	inf_close_stmt $stmt

	set numRows [db_get_nrows $res]
	set course_idx 0
	set course_list [list]
	for {set i 0} {$i < $numRows} {incr i} {
		if {[lsearch $course_list [db_get_col $res $i ocb_id]] == -1} {
			# new course
			lappend course_list [db_get_col $res $i ocb_id]
			set OC_BATCH($course_idx,ocb_id)       [db_get_col $res $i ocb_id]
			set OC_BATCH($course_idx,course_name)  [db_get_col $res $i course]
			set OC_BATCH($course_idx,meeting_date) [db_get_col $res $i meeting_date]
			set OC_BATCH($course_idx,num_batches) 0
			incr course_idx
		} else {
			continue
		}
	}
	for {set i 0} {$i < $numRows} {incr i} {
		set course_idx [lsearch $course_list [db_get_col $res $i ocb_id]]

		set batch_idx $OC_BATCH($course_idx,num_batches)
		if {[db_get_col $res $i batch_ref_id] != ""} {
			set OC_BATCH($course_idx,$batch_idx,batch_ref_id)  [db_get_col $res $i batch_ref_id]
		} else {
			set OC_BATCH($course_idx,$batch_idx,batch_ref_id) -1
		}
		set OC_BATCH($course_idx,$batch_idx,cr_date)       [db_get_col $res $i cr_date]
		if {$OC_BATCH($course_idx,$batch_idx,cr_date) == ""} {
			set OC_BATCH($course_idx,$batch_idx,is_processed) 0
		} else {
			set OC_BATCH($course_idx,$batch_idx,is_processed) 1
		}
		if {$OC_BATCH($course_idx,meeting_date) != "" && [clock scan $OC_BATCH($course_idx,meeting_date)] < [clock scan "today 00:00"]
			&& $OC_BATCH($course_idx,$batch_idx,is_processed) == 0} {
			set OC_BATCH($course_idx,in_past) 1
		} else {
			set OC_BATCH($course_idx,in_past) 0
		}
		incr OC_BATCH($course_idx,num_batches)
	}

	db_close $res

	tpSetVar  numTracks   [llength $course_list]
	tpBindVar OCBId       OC_BATCH ocb_id        courseIndex
	tpBindVar numBatches  OC_BATCH num_batches   courseIndex
	tpBindVar Course      OC_BATCH course_name   courseIndex
	tpBindVar CourseDate  OC_BATCH meeting_date  courseIndex
	tpBindVar InPast      OC_BATCH in_past       courseIndex
	tpBindVar BatchID     OC_BATCH batch_ref_id  courseIndex batchIndex
	tpBindVar BatchDate   OC_BATCH cr_date       courseIndex batchIndex
	tpBindVar IsProcessed OC_BATCH is_processed  courseIndex batchIndex
	# End of Batch Section

	# Get list of all meetings added
	set sql {
		select
			ocb.ocb_id,
			ocb.course,
			ocb.meeting_date
		from
			tOnCourseBatch ocb
		order by
			ocb.meeting_date
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]
	
	for {set i 0} {$i < $nrows} {incr i} {
		set OC_MEETINGS($i,ocb_id)       [db_get_col $res $i ocb_id]
		set OC_MEETINGS($i,meeting_name) [db_get_col $res $i course]
		set OC_MEETINGS($i,meeting_date) [db_get_col $res $i meeting_date]
	}

	db_close $res

	tpSetVar  numMeetings $nrows
	tpBindVar MeetingOCBId OC_MEETINGS ocb_id       meetingIndex
	tpBindVar MeetingName  OC_MEETINGS meeting_name meetingIndex
	tpBindVar MeetingDate  OC_MEETINGS meeting_date meetingIndex

	set source_dir "[OT_CfgGet ONCOURSE_INPUT_DIR]/to_process/"
	set next_file    "OnCoursePunters.csv"
	set next_action  ADJ

	set files [glob -nocomplain -tails -directory $source_dir *]
	set i 0
	foreach filename $files {
		set OC_FILES($i,filename) $filename
		if {$filename == $next_file} {
			set OC_FILES($i,focus)    $next_action
		} else {
		set OC_FILES($i,focus) ""
		}
		incr i
	}
	set num_files  $i

	tpBindString ONCOURSE_UPLOAD_PATH  $source_dir
	tpSetVar numFiles $num_files
	tpBindVar OCFileName OC_FILES filename fileIdx
	tpBindVar OCFocus    OC_FILES focus    fileIdx

	asPlayFile -nocache  oncourse/oncourse_trans.html
}



proc ADMIN::ONCOURSE::do_oncourse {} {
	global DB
	switch -- [reqGetArg SubmitName] {
		upload_bets {
			set filename     [reqGetArg filename]
			set filetype     [reqGetArg filetype]
			set upload_dir   [OT_CfgGet UPLOAD_DIR]

			foreach {course meeting_date ocb_id} [split [reqGetArg course] '/'] {break}
			
			set source_dir   "[OT_CfgGet ONCOURSE_INPUT_DIR]/to_process/"
			set warn_list    {}

			if {[catch {

				set oc_file_path [_upload_oc_file $filename $filetype BETS $source_dir $upload_dir]
				OT_LogWrite DEV "oc_file_path is: $oc_file_path"

				set warn_list [_process_csv $oc_file_path]
				OT_LogWrite DEV "processed on course csv file. warnings so far: $warn_list"

				set date_suffix [clock format [clock seconds] -format "%Y-%m-%d_%H:%M:%S"]
				set manbets_filepath "${upload_dir}/man_bets/${filename}_${date_suffix}"
				set manbets_filename "${filename}_${date_suffix}"
				set rep_code [_create_manbets_file $manbets_filepath $course]
				OT_LogWrite DEV "manbets_filepath is: $manbets_filepath"

				# Insert any new oncourse cust accounts from the bets in the file
				set warn_list [_insert_betting_punters $course]
			} msg]} {
				global errorInfo
				err_bind $msg
				OT_LogWrite ERROR "There was an ONCOURSE error: $msg"
				OT_LogWrite DEV "Stack-trace for error: $errorInfo"
				go_oncourse_trans
				return
			} else {
				# Bind warnings or errors.
				if {[llength $warn_list]} {
					OT_LogWrite 1 "File uploaded with errors."
					err_bind "<br>[join $warn_list {<br>}]"
				} else {
					OT_LogWrite 1 "File uploaded successfully."
					msg_bind "Uploaded file successfully"
				}

				reqSetArg FullName      $manbets_filename
				reqSetArg FileType      "man_bets"
				reqSetArg upload_type   "MISC"
				reqSetArg use_batch_ref 1
				ob::log::write DEV "ONCOURSE:  Course value is: $course"
				reqSetArg course        $course
				reqSetArg rep_code      $rep_code
				reqSetArg ocb_id        $ocb_id
				tpSetVar UPLOADED 1
				ADMIN::UPLOAD::go_upload_file
			}
		}
		upload_adj {
			set filename     [reqGetArg filename]
			set filetype     [reqGetArg filetype]
			set upload_dir   [OT_CfgGet UPLOAD_DIR]

			foreach {course meeting_date ocb_id} [split [reqGetArg course] '/'] {break}
			set source_dir   "[OT_CfgGet ONCOURSE_INPUT_DIR]/to_process/"

			if {[catch {
				set oc_file_path [_upload_oc_file $filename $filetype ADJ $source_dir $upload_dir]
				OT_LogWrite DEV "oc_file_path is: $oc_file_path"

				set warn_list [_process_csv $oc_file_path]
				OT_LogWrite DEV "warnings so far: $warn_list"

				set date_suffix [clock format [clock seconds] -format "%Y-%m-%d_%H:%M:%S"]
				set manadj_filepath "${upload_dir}/adjustments/${filename}_${date_suffix}"
				set manadj_filename "${filename}_${date_suffix}"
				# We switched to using a user specified meeting_name, 
				# but I'm leaving the definition of meeting_key in case we need it.
				set meeting_key [_create_manadj_file $manadj_filepath $course]
				OT_LogWrite DEV "manadj_filepath is: $manadj_filepath"
			} msg]} {
				global errorInfo
				err_bind $msg
				OT_LogWrite DEV "There was an ONCOURSE error: $msg"
				OT_LogWrite DEV "Stack-trace for error: $errorInfo"
				go_oncourse_trans
				return
			} else {
				reqSetArg FullName      $manadj_filename
				reqSetArg FileType      "adjustments"
				reqSetArg upload_type   "PMT"
				reqSetArg use_batch_ref 1
				reqSetArg course        $course
				reqSetArg ocb_id        $ocb_id
				tpSetVar UPLOADED 1
				ADMIN::UPLOAD::go_upload_file
			}
		}
		del_oc_file {
			set filename [reqGetArg filename]
			set filepath "[OT_CfgGet ONCOURSE_INPUT_DIR]/to_process/"
			OT_LogWrite DEV "target is: ${filepath}${filename}"
			if {[catch {file delete -force -- "${filepath}${filename}"} msg]} {
				err_bind "Unable to delete file $filename : $msg"
			}
			go_oncourse_trans
		}
		download_punters {
			set download_dir [OT_CfgGet ONCOURSE_DIR]

			if {[catch {
				set oc_file_path [_create_punters_file $download_dir]
				OT_LogWrite DEV "oc_file_path is: $oc_file_path"
			} msg]} {
				err_bind $msg
				OT_LogWrite 1 "There was an ONCOURSE error: $msg"
				go_oncourse_cust
				return
			} else {
				msg_bind "Downloaded file successfully to $oc_file_path"
				OT_LogWrite 1 "Uploaded file successfully: $msg"
				go_oncourse_cust
			}

		}
		upload_punters {
			set filename    [reqGetArg filename]
			set filetype    [reqGetArg filetype]
			set upload_dir  [OT_CfgGet UPLOAD_DIR]

			if {[catch {
				set oc_file_path [_do_upload $filename $filetype $upload_dir]
				OT_LogWrite DEV "oc_file_path is: $oc_file_path"

				set warn_list [_process_punter_file $oc_file_path]
				OT_LogWrite DEV "warnings so far: $warn_list"
			} msg]} {
				err_bind $msg
				OT_LogWrite 1 "There was an ONCOURSE error: $msg"
				go_oncourse_cust
				return
			} else {
				if {[llength $warn_list]} {
					OT_LogWrite 1 "File uploaded with errors."
					err_bind "<br>[join $warn_list {<br>}]"
				} else {
					OT_LogWrite 1 "File uploaded successfully."
					msg_bind "Uploaded file successfully"
				}
				go_oncourse_cust
				return
			}
		}
		remove_punter {
			set acct_no [reqGetArg acct_no]
			if {[catch {
				_remove_oc_cust $acct_no
			} msg]} {
				err_bind $msg
				go_oncourse_cust
			} else {
				msg_bind "Removed customer $acct_no from Punters List"
				go_oncourse_cust
			}
		}
		set_batch {
			set batch_ref_id  [reqGetArg batch_ref_id]
			set ocb_id  [reqGetArg ocb_id]

			set course        [reqGetArg course_$ocb_id]
			set meeting_date  [reqGetArg date_$ocb_id]
			set process_date  [reqGetArg process_date_$batch_ref_id]

			if {$batch_ref_id != "" && $ocb_id != ""} {
				if {[catch {
					_setup_oc_batch $batch_ref_id $ocb_id $course $process_date $meeting_date
				} msg]} {
					err_bind $msg
					go_oncourse_trans
				} else {
					msg_bind "Successfully Modified Course $course"
					go_oncourse_trans
				}
			} else {
				go_oncourse_trans
			}
		}
		remove_batch {
			set batch_ref_id [reqGetArg batch_ref_id]

			# Delete batch reference from tOCMeetingBatches
			set stmt [inf_prep_sql $DB {delete from tOCMeetingBatches where batch_ref_id = ?}]
			if {[catch {db_close [inf_exec_stmt $stmt $batch_ref_id]} msg]} {
				err_bind "$msg"
			}
			catch {inf_close_stmt $stmt}

			# Delete batch from tBatchReference
			set stmt [inf_prep_sql $DB {delete from tBatchReference where batch_ref_id = ?}]
			if {[catch {db_close [inf_exec_stmt $stmt $batch_ref_id]} msg]} {
				err_bind "$msg"
			}
			catch {inf_close_stmt $stmt}
			go_oncourse_trans
		}
		add_meeting_batch {
			set meeting_name [reqGetArg meeting_name]
			set meeting_date [reqGetArg meeting_date]

			set sql {
				insert into
					tOnCourseBatch(meeting_date, course)
				values
					(?, ?)
			}
			set stmt [inf_prep_sql $DB $sql]
			if {[catch {db_close [inf_exec_stmt $stmt $meeting_date $meeting_name]} msg]} {
				err_bind "$msg"
			}
			catch {inf_close_stmt $stmt}
			go_oncourse_trans
		}
		delete_meeting {
			set ocb_id [reqGetArg ocb_id]

			# Get all batch ref IDs for the meeting
			set sql {
				select
					mb.batch_ref_id
				from
					tOCMeetingBatches mb
				where
					ocb_id = ?
			}

			set stmt [inf_prep_sql $DB $sql]
			set rs [inf_exec_stmt $stmt $ocb_id]
			catch {inf_close_stmt $stmt}

			set nrows [db_get_nrows $rs]

			# Delete all the entries in tOCMeetingBatches for the meeting
			set sql {
				delete from
					tOCMeetingBatches
				where
					ocb_id = ?
			}

			set stmt [inf_prep_sql $DB $sql]
			inf_exec_stmt $stmt $ocb_id
			catch {inf_close_stmt $stmt}

			# Delete the batch references
			set stmt [inf_prep_sql $DB {delete from tBatchReference where batch_ref_id = ?}]
			for {set i 0} {$i < $nrows} {incr i} {
				set batch_ref_id [db_get_col $rs $i batch_ref_id]
				if {[catch {db_close [inf_exec_stmt $stmt $batch_ref_id]} msg]} {
					err_bind "$msg"
				}
			}
			catch {inf_close_stmt $stmt}

			# Delete the meeting
			set sql {
				delete from
					tOnCourseBatch
				where
					ocb_id = ?
			}

			set stmt [inf_prep_sql $DB $sql]
			if {[catch {db_close [inf_exec_stmt $stmt $ocb_id]} msg]} {
				err_bind "$msg"
			}
			catch {inf_close_stmt $stmt}
			db_close $rs
					
			go_oncourse_trans
		}
		default {
			OT_LogWrite DEV "Unrecognized SubmitName [reqGetArg SubmitName]"
			go_oncourse_trans
		}
	}
}



proc ADMIN::ONCOURSE::_process_csv {file_path} {
	_define_OC_FORMATS
	_initialize_OC_DATA
	_initialize_OC_REPS
	set warn_list [_read_csv $file_path]
	set warn_list [concat $warn_list [_check_consistency]]

	return $warn_list
}



proc ADMIN::ONCOURSE::_initialize_OC_DATA {} {
	variable OC_DATA
	variable OC_FORMATS

	array unset OC_DATA

	foreach row_type $OC_FORMATS(row_type_list) {
		set OC_DATA($row_type,key_list) [list]
	}

}



proc ADMIN::ONCOURSE::_initialize_OC_REPS {} {
	global OC_REPS
	array unset OC_REPS
}



# Read the data from On-Course format file.
proc ADMIN::ONCOURSE::_read_csv {filepath} {

	variable OC_DATA
	variable OC_FORMATS
	set warn_list [list]

	set f [open $filepath r]
	set file_as_list [split [read $f] \n]
	close $f

	# Build OC_DATA based on format described by OC_FORMATS
	#
	OT_LogWrite DEV "length of file_as_list: [llength $file_as_list]"
	for {set i 0} {$i < [llength $file_as_list]} {incr i} {
		set line_num [expr $i + 1]
		set line_as_list [split [lindex $file_as_list $i] ,]
		OT_LogWrite DEV "$line_as_list"
		set line_type [lindex $line_as_list 0]
		if {[lsearch $OC_FORMATS(row_type_list) $line_type] != -1} {
			# Setup key information
			set key_col $OC_FORMATS($line_type,key_col)
			foreach {key_col_desc key_col_num key_pattern} \
			        $OC_FORMATS($line_type,format_list,$key_col) \
			        {}
			if {$key_col_num >= 0} {
				set key [string trim [lindex $line_as_list $key_col_num]]
			} else {
				# this is for if the row has no unique identifier (like cheques)
				# so we make one.  Kinda stupid, but oh well.
				set key 0;
				while {[lsearch $OC_DATA($line_type,key_list) $key] != -1} {incr key}
				OT_LogWrite DEV "value for key column \"$key_col_desc\": $key"
			}


			# Check for empty or duplicate keys
			if {$key != "" && [lsearch $OC_DATA($line_type,key_list) $key] <= 0} {

				# load each desired value in the row
				foreach column $OC_FORMATS($line_type,column_list) {
					# get info about this column format from OC_FORMATS
					foreach {col_desc col_num pattern} \
					        $OC_FORMATS($line_type,format_list,$column) \
					        {}

					# Actually set the value
					set OC_DATA($line_type,$key,$column) [string trim [lindex $line_as_list $col_num]]

					# Check that column value is in the correct format
					if {![regexp -- $pattern  $OC_DATA($line_type,$key,$column)]} {
						set pattern_desc [_translate $pattern]
						error "Error in line #$line_num: \"$col_desc\" value ($OC_DATA($line_type,$key,$column)) must be of pattern $pattern_desc"
					}
				}

				# If we've got a voided bet, remove it immediately
				if {$line_type == "B" && $OC_DATA($line_type,$key,void_bet) == 1} {
					# do nothing
				} else {
					lappend OC_DATA($line_type,key_list) $key
				}

			} else {
				OT_LogWrite DEV "value for key column \"$key_col_desc\": $key"
				error "Error in line $line_num: \"$key_col_desc\" value ($key) must be unique"
			}
		} else {
			lappend warn_list "Warning:  Line $line_num has unknown line type = $line_type"
		}
	}
	OT_LogWrite DEV "OC_DATA is: "
	foreach key [array names OC_DATA] {
		OT_LogWrite DEV "  $key      $OC_DATA($key)"
	}

	return $warn_list
}



# Check to see that the data in OC_DATA is internally consistent
# raises an error if there is problem with the data.
# TODO:  There are out-standing questions to william hill
#        about the examples given, So this is a placeholder proc
# Update:    WillHill can't figure out what they want us to check,
#            So this will remain a placeholder proc.
proc ADMIN::ONCOURSE::_check_consistency {} {

	variable OC_DATA


	# Check internal consistency of Bet details.
	# i.e. Make sure that each line represents a valid bet
	foreach bet_id $OC_DATA(B,key_list) {
		# split workflow by transtype
		# only trans types 1 and 2 recognized right now.
		

		switch -- $OC_DATA(B,$bet_id,trans_type) {
			1 {
			}
			2 {
			}
			default {
				error "Unrecognized Transaction Type: $OC_DATA(B,$bet_id,trans_type)"
			}
		}
	}



	# Check internal consistency of Runner details
	# Check that each Runner line is consistent with associated Bet details

	# Check internal consistency of Race details
	# Check that each Race is consistent with associated Bet details
	# Check that each Race is consistent with associated Runner details

	# Check internal consistency of Cheque/cash details

	# Check internal consistency of Meeting details
	# Check that each Meeting is consistent with associated Race details
	# Check that each Meeting is consistent with associated Cheque details

}


# Creates a file of the format needed to upload manual bets.
# Returns the rep code for the first meeting key
proc ADMIN::ONCOURSE::_create_manbets_file {target_filepath course} {

	variable OC_DATA

	if {[catch {
		set f [open $target_filepath w]
	} msg2]} {
		error $msg2
	}

	if {[catch {
		puts $f "ACCOUNT NUMBER,DESCRIPTION,CATEGORY,CLASS,TYPE,CHANNEL,STAKE,PAY NOW,SETTLE AT,TAX TYPE,TAX RATE,TAX,RESULT,WINNINGS,REFUNDS,SETTLEMENT COMMENT,ACTUAL DATE PLACED,REP CODE,COURSE TYPE"
	
		#create a line in the file for every bet
		foreach bet_id $OC_DATA(B,key_list) {
	
			# Type 1 is a bet which is settled by the On Course Rep at the race.
			# All that needs doing is to adjust the OnCourse Rep's account.
			# Therefore we simply treat it as a manual adjustment
			set race_key     $OC_DATA(B,$bet_id,race_key)
			set race_time    $OC_DATA(R,$race_key,race_time)
			set runner_name  $OC_DATA(H,$OC_DATA(B,$bet_id,runner_key),runner_name)
			set meeting_key  $OC_DATA(R,$race_key,meeting_key)
			set meeting_date $OC_DATA(M,$meeting_key,date)
			set price        $OC_DATA(B,$bet_id,price)

			set settlementComment ""
	
			# set up comment if Horse was withdrawn and Rule4 applied.
			set rule4_comment ""
			if {$OC_DATA(B,$bet_id,rule4) != 0  &&  $OC_DATA(B,$bet_id,rule4) != ""} {
				if {![OT_CfgGet ONCOURSE_RULE4_CORRECT 1]} {
					#
					# There is bug in Will Hill's oncourse code that returns the rule4 deduction
					# as £1.00 - <rule_4_deduction>. Therefore we need to convert it back.
					# 
					set OC_DATA(B,$bet_id,rule4) [expr {1.00 - $OC_DATA(B,$bet_id,rule4)}]
				}
				set rule4_comment  "with Rule4 applied at $OC_DATA(B,$bet_id,rule4)"
			}
	
			set meeting_title $course
			set rep_code $OC_DATA(M,$meeting_key,rep_code)
	
			switch -- $OC_DATA(B,$bet_id,trans_type) {
				1 {
					# Handling Book Cash Bets against the Representative's account.
					switch -- $OC_DATA(B,$bet_id,hedged) {
						1 {
							set desc "Hedging bet on $runner_name at $race_time $meeting_date $meeting_title at price $price $rule4_comment"
							set acct_num    [_get_acct_num $rep_code]
							set settlementComment "Settled OnCourse"
							set hedge_factor -1
						}
						0 -
						default {
							set desc "On-Course bet on $runner_name at $race_time $meeting_date $meeting_title at price $price $rule4_comment"
							set acct_num    [_get_acct_num $rep_code]
							set settlementComment "Settled OnCourse"
							set hedge_factor 1
						}
					}
				}
				2 {
					# We are not handling Hedging bets on a customer's account (trans_type = 2)
					# so all trans_type = 2 bets are handled as follows
					set rep_acct_no [_get_acct_num $rep_code]
					set desc "On-Course bet on $runner_name at $race_time $meeting_date $meeting_title at price $price $rule4_comment"
					set acct_num    $OC_DATA(B,$bet_id,account_num)
					set settlementComment "Placed by Rep acct #$rep_acct_no"
					set hedge_factor 1
				}
				default {
					error "Unrecognized Transaction Type: $OC_DATA(B,$bet_id,trans_type)"
				}
			}
	
			switch -- $OC_DATA(B,$bet_id,paid_out) {
				0 {
					set result "L"
					set res_factor 0.00
				}
				1 {
					set result "W"
					set res_factor -1
				}
				default {error "Unrecognized value for 'Paid Out' on bet #$bet_id"}
			}
			if {$OC_DATA(B,$bet_id,void_bet) == 1} {
					set result "V"
					set refund $stake
					set res_factor 0.00
			} else {
				set refund 0.00
			}
			set stake       [format %.2f [expr $hedge_factor * ($OC_DATA(B,$bet_id,win_stake) + $OC_DATA(B,$bet_id,place_stake)) / 100.00]]
			set winnings    [format %.2f [expr $res_factor * $hedge_factor * ($OC_DATA(B,$bet_id,win_ret)   + $OC_DATA(B,$bet_id,pl_ret)) / 100.00]]

			if {$OC_DATA(B,$bet_id,paid_out) == 1} {
				# We display the winnings including the stake
				set winnings    [expr {$stake + $winnings}]
			}

			# re-format date from dd/mm/yy to yy-mm-dd and then append time
			set d [split $OC_DATA(B,$bet_id,date) {/}]
			set date_placed "[lindex $d 2]-[lindex $d 1]-[lindex $d 0]"
			set time_date_placed "$date_placed $OC_DATA(B,$bet_id,time)"

			# It's currently the case that we only ever upload Book bets
			# through the on course transactions screen.
			set course_type "B"

			puts $f "$acct_num,$desc,,,,C,$stake,Y,,S,0,0,$result,$winnings,$refund,$settlementComment,$time_date_placed,$rep_code,$course_type"

		}
	} msg]} {
		close $f
		error $msg
	} else {
		close $f
	}

	set meeting_key [lindex $OC_DATA(M,key_list) 0]
	return $OC_DATA(M,$meeting_key,rep_code)

}



proc ADMIN::ONCOURSE::_create_manadj_file {target_filepath course} {

	variable OC_DATA

	set bad 0

	if {[catch {
		set f [open $target_filepath w]
	
		puts $f "USERNAME,ACCOUNT NUMBER,LAST NAME,DESCRIPTION,WITHDRAWABLE,AMOUNT,CURRENCY CODE,TYPE,BOOKMAKER ACCOUNT"
	
		if {[llength $OC_DATA(C,key_list)] == 0} {
			error "There are no rows beginning with C in the on-course file, so no manual adjustments to process."
		}
	
		set meeting_title $course
	
		#create a line in the file for every cash/check
		foreach c_id $OC_DATA(C,key_list) {
			set acct_num $OC_DATA(C,$c_id,acct_num)
			set currency_code "GBP"
			set amount    [format %.2f [expr {$OC_DATA(C,$c_id,cash) / 100.00}]]
			set meeting_key  $OC_DATA(C,$c_id,meeting_key)
			set rep_acct_no [_get_acct_num $OC_DATA(M,$meeting_key,rep_code)]
			set meeting_date $OC_DATA(M,$meeting_key,date)
			set description  "Processed by Rep acct# $rep_acct_no on $meeting_date at $meeting_title"
	
			puts $f ",$acct_num,,$description,Y,$amount,$currency_code,ONCR"
		}
	} msg]} {
		close $f
		set bad 1
		error $msg
	}

	if {!$bad} {
		close $f
	}

	return [lindex $OC_DATA(M,key_list) 0]

}



proc ADMIN::ONCOURSE::_do_upload {filename filetype upload_dir} {

	global REQ_FILES

	OT_LogWrite 1 "filename: $filename"
	OT_LogWrite 1 "filetype: $filetype"
	OT_LogWrite 1 "upload_dir: $upload_dir"

	set date_suffix [clock format [clock seconds] -format "%Y-%m-%d_%H:%M:%S"]

	set fname "${upload_dir}/${filetype}/${filename}_${date_suffix}"

	if {[catch {
		set fp [open $fname w]
	} msg]} {
		error "Failed to write file $fname ($msg)"
	}

	puts -nonewline $fp $REQ_FILES(filename)

	close $fp

	return $fname

}



proc ADMIN::ONCOURSE::_upload_oc_file {filename filetype processing_type source_dir target_dir} {

	set date_suffix [clock format [clock seconds] -format "%Y-%m-%d_%H:%M:%S"]

	set source_fname "${source_dir}/${filename}"

	set target_fname "${target_dir}/${filetype}/${processing_type}_${filename}_${date_suffix}"

	if {[catch {
		file copy -force -- $source_fname $target_fname
	} msg]} {
		error "Failed to copy file file from $source_fname $target_fname ($msg)"
	}

	return $target_fname

}



# Placeholder
proc ADMIN::ONCOURSE::_translate {key} {
	return $key
}


# this keeps it from querrying the db a million times when building the file
proc ADMIN::ONCOURSE::_get_acct_num {rep_code} {
	global DB
	global OC_REPS

	if {[info exists OC_REPS($rep_code)]} {
		return $OC_REPS($rep_code)
	}

	set sql {
		select
			c.acct_no,
			r.status
		from
			tOnCourseRep r,
			tAcct a,
			tCustomer c
		where
			r.rep_code  = ? and
			r.acct_id = a.acct_id and
			a.cust_id = c.cust_id
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $rep_code]
	inf_close_stmt $stmt

	if {[db_get_nrows $res] == 1} {
		if {[db_get_col $res 0 status] != "A"} {
			OT_LogWrite DEBUG "Rep account is DELETED"
			error "Rep '$rep_code' has been DELETED. Cannot allow access."
		} else {
			set OC_REPS($rep_code) [db_get_col $res 0 acct_no]
		}
	} else {
		OT_LogWrite DEBUG "Problem getting Rep Account Num"
		error "Problem getting Rep Account Num.  Does Rep '$rep_code' have a Fielding and Hedging account?"
	}

	db_close $res
	return $OC_REPS($rep_code)
}



proc ADMIN::ONCOURSE::_process_punter_file {file_path} {
	global DB
	set warn_list {}

	set f [open $file_path r]
	set file_as_list [split [read $f] \n]
	close $f

	for {set i 0} {$i < [llength $file_as_list]} {incr i} {
		set line_num [expr $i + 1]
		set line [string trim [lindex $file_as_list $i]]
		if {$line == ""} {continue}
		set line_as_list [split $line ,]

		if {$i == 0} {
			set course_id [string trim [lindex $line_as_list 0]]
			if {$course_id == ""} {
				lappend warn_list "Cannot have an empty course name in line $line_num."
			}
		} else {

			set acct_no [string trim [lindex $line_as_list 0]]

			# add this course_id to this punter if it isn't there already.
			set sql {
				execute procedure pInsOnCourseCust (
					p_acct_no = ?,
					p_course  = ?
				)
			}
			set stmt [inf_prep_sql $DB $sql]
			if {[catch {
				set res [inf_exec_stmt $stmt $acct_no $course_id]
				inf_close_stmt $stmt
			} msg]} {
				lappend warn_list "Problem parsing line $line_num.  Check that the account number is valid. Error message: $msg"
			}
			
			catch {db_close $res}
		}
	}

	return $warn_list
}


proc ADMIN::ONCOURSE::_insert_betting_punters {course_id} {
	global DB

	variable OC_DATA

	set warn_list {}

	set acct_no_done [list]
	foreach bet_id $OC_DATA(B,key_list) {
		set acct_no $OC_DATA(B,$bet_id,account_num)
		if {$OC_DATA(B,$bet_id,trans_type) == 2 && \
		    $acct_no != "" && \
		    [lsearch $acct_no_done $acct_no] == -1} {
			# We only care about bets on a customers account not on a representatives account

			# add this course_id to this punter if it isn't there already.
			set sql {
				execute procedure pInsOnCourseCust (
					p_acct_no = ?,
					p_course  = ?
				)
			}
			set stmt [inf_prep_sql $DB $sql]
			if {[catch {
				set res [inf_exec_stmt $stmt $acct_no $course_id]
				inf_close_stmt $stmt
			} msg]} {
				lappend warn_list "Problem parsing acct_no=$acct_no for course_id=$course_id.  Check that the account number is valid. Error message: $msg"
			}
			
			catch {db_close $res}

			lappend acct_no_done $acct_no
		}
	}

	return $warn_list
}



proc ADMIN::ONCOURSE::_remove_oc_cust {acct_no} {
	global DB

	set sql {
		delete from
			tOnCourseCust
		where
		    acct_no = ?
	}
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt  $stmt $acct_no]
	inf_close_stmt $stmt
	db_close $res
}



proc ADMIN::ONCOURSE::_setup_oc_batch {batch_ref_id ocb_id course process_date meeting_date} {
	global DB

	set sql_no_meeting {
		execute procedure pInsOnCourseBatch (
			p_batch_ref_id = ?,
			p_ocb_id       = ?,
			p_course       = ?,
			p_process_date = ?,
			p_meeting_date = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql_no_meeting]
	set res  [inf_exec_stmt $stmt $batch_ref_id $ocb_id $course $process_date $meeting_date]

	inf_close_stmt $stmt
	db_close $res
}



proc ADMIN::ONCOURSE::_create_punters_file {dest_dir} {
	global DB
	variable punter_sql

	set stmt [inf_prep_sql $DB $punter_sql]
	set res  [inf_exec_stmt  $stmt]
	inf_close_stmt $stmt

	# Begin Output to file format DDMM_PunterList.csv
    set filename $dest_dir/[clock format [clock seconds] -format "%d%m"]_PunterList.csv
	set f [open $filename w]
	puts $f "GENERAL"
	for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
		puts $f "[db_get_col $res $i acct_no],[db_get_col $res $i title],[string range [db_get_col $res $i fname] 0 0] [string range [db_get_col $res $i mname] 0 0],[db_get_col $res $i lname]"
	}
	close $f

	return $filename
}

