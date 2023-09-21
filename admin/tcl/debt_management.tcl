# $Id: debt_management.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# Debt management for credit customers
#
# Admin screens:
#
# Debt Chase            - to select customers who should go into debt man.
#                       process
# Debt Management       - manage customers, change their status, send letters etc.
# Debt Letters Config   - configuration of customer letter templates
#                       for each state
#
# Procs:
#
# add_cust_flag         - Add a customer status flag
# change_cust_debt      - Change customer's status in tCustomerDebt
# change_state          - Change between states in debt diary
# change_states         - Change states for selected customers
# create_letter         - Create a new instance of a letter template
# do_cfg                - Configure debt states
# do_debt_man           - Do a debt management action
# do_debt_man_sel       - Do a debt management selection
# do_letter_cfg         - Set which letter templates can be used for debt state
# get_allowed_states    - which debt states can to be accessed by current user
# get_count_ca          - Get # of times a customer was removed
#                         from ChaseArrears
# get_count_ledger      - Get count of times in ledger stop
# get_letters           - Get list of existing, not-yet-sent letters
#                         for this template and display them
# get_state_id          - Get debt state id from state code
# go_cfg                - View the Config screen
# go_debt_man           - Display debt management screen
# go_debt_man_sel       - Display debt management selection screen
# go_letter_cfg         - Display letter template selection screen
# go_update_details     - Display page for adding a note
# ins_debt_diary        - Insert a new record to debt diary
# move_to_debt_diary    - Move selected customers in tCustomerDebt to tDebtDiary
# remove_cust_flag      - Remove a customer status flag
# remove_from_debt_man  - Remove selected customers from the debt management
#                         selection process
# remove_from_debt_man_sel
# send_letters           - Send letters to selected customers
# update_details        - Update debt diary details
#



namespace eval ADMIN::DEBT_MANAGEMENT {

asSetAct ADMIN::DEBT_MANAGEMENT::DoUpdateDetails [namespace code do_update_details]
asSetAct ADMIN::DEBT_MANAGEMENT::GoUpdateDetails [namespace code go_update_details]
asSetAct ADMIN::DEBT_MANAGEMENT::GoDebtMan       [namespace code go_debt_man]
asSetAct ADMIN::DEBT_MANAGEMENT::DoDebtMan       [namespace code do_debt_man]
asSetAct ADMIN::DEBT_MANAGEMENT::GoDebtManSel    [namespace code go_debt_man_sel]
asSetAct ADMIN::DEBT_MANAGEMENT::DoDebtManSel    [namespace code do_debt_man_sel]
asSetAct ADMIN::DEBT_MANAGEMENT::GoDebtManualEntry [namespace code go_manual_entry]
asSetAct ADMIN::DEBT_MANAGEMENT::DoDebtManualEntry [namespace code do_manual_entry]

if {![OT_CfgGet RIGHTNOW_DEBT_MAN_ENABLED 1]} {
	asSetAct ADMIN::DEBT_MANAGEMENT::DoDebtManCfg    [namespace code do_cfg]
	asSetAct ADMIN::DEBT_MANAGEMENT::GoDebtManCfg    [namespace code go_cfg]
	asSetAct ADMIN::DEBT_MANAGEMENT::GoDebtManSelArg [namespace code go_debt_man_sel_arg]
	asSetAct ADMIN::DEBT_MANAGEMENT::GoDebtLetterCfg [namespace code go_letter_cfg]
	asSetAct ADMIN::DEBT_MANAGEMENT::DoDebtLetterCfg [namespace code do_letter_cfg]
}

#
# ----------------------------------------------------------------------------
# Display debt management screen
# ----------------------------------------------------------------------------
#
proc go_debt_man args {

	ob::log::write INFO {==> go_debt_man}

	global DB
	global USERNAME USERID
	global DEBT_MAN

	set act [reqGetArg SubmitName]

	if {$act == ""} {
		# display query page
		bind_allowed_states
		bind_csort

		asPlayFile -nocache debt_man_arg.html
		return
	}

	# display result list

	set debt_state   [reqGetArg DebtState]
	set diary_status [reqGetArg DiaryStatus]
	set review_date  [reqGetArg ReviewDate]
	set acct_no      [reqGetArg AcctNo]
	set csort        [reqGetArg csort]

	set where_acct ""
	set where_debt_state   ""
	set where_diary_status ""
	set where_review_date  ""
	set where_csort        ""
	set csort_outer        "outer"

	if {$diary_status == ""} {
		set diary_status "A"
	}

	if { $acct_no != ""} {
		set where_acct "and cust.acct_no = '$acct_no'"
		set where_diary_status "and d.status = '$diary_status'"
	} elseif {$acct_no == ""} {

		if {$csort != ""} {
			set where_csort "and csort.cust_code = '$csort'"
			set csort_outer ""
		}

		if {$debt_state == ""} {
			set state [get_state_id [OT_CfgGet DEBT_MNG_INITIAL_STATE "DS1"]]
		}
		set where_debt_state "and d.debt_state_id = $debt_state"

		set where_diary_status "and d.status = '$diary_status'"

		if {$review_date != ""} {
			set where_review_date "and d.review_date ='$review_date'"
		} else {
			set where_review_date "and d.review_date <= CURRENT"
		}
	}


	set debt_state_ids [join [get_allowed_states 1] ,]

	set query_debt_diary [subst {
		select
			EXTEND(d.cr_date, YEAR to DAY) as cr_date,
			EXTEND(d.review_date, YEAR to DAY) as review_date,
			EXTEND(d.reviewed_at, YEAR to DAY) as reviewed_at,
			d.oper_id,
			d.cust_id,
			d.status,
			cdd.notes,
			cust.username,
			cr.fname,
			cr.mname,
			cr.lname,
			s.code,
			s.description,
			s.debt_state_id,
			cr.code,
			d.letter_sent,
			s.next_debt_state_id,
			d.debt_diary_id,
			cust.acct_no,
			EXTEND(cust.cr_date, YEAR to DAY) as opened,
			ac.balance + ac.sum_ap as balance,
			EXTEND(cdd.last_payment_date, YEAR to DAY) as last_payment_date,
			cdd.last_payment_amount,
			cdd.max_bet_stake,
			NVL(r.pmt_amount,cdd.balance) as st_balance,
			cdd.stmt_id,
			cdd.largest_payment,
			csort.desc as cust_group,
			cdd.count_chase,
			cdd.count_arrears,
			(cdd.legacy_count_ledger + cdd.count_ledger) as count_ledger,
			(cdd.legacy_count_oad + cdd.count_oad) as count_oad,
			cdd.count_suspended
		from
			tDebtDiary d,
			tCustomer  cust,
			tCustomerReg cr,
			tDebtState s,
			tAcct ac,
			tCustDebtData cdd,
			outer tStmtRecord r,
			$csort_outer tCustCode csort

		where
			cr.code = csort.cust_code and
			(exists (
				select 1
				from
					tAdminUserOp uo
				where
					uo.user_id = ?
				and
					uo.action = 'DebtManSort_' || csort.cust_code
			) or exists (
				select 1
				from
					tAdminUserGroup ug,
					tAdminGroupOp gop
				where
					ug.user_id = ? and
					ug.group_id = gop.group_id and
					gop.action = 'DebtManSort_' || csort.cust_code
			) or exists (
				select 1
				from
					tAdminPosnGroup pg,
					tAdminGroupOp gop,
					tAdminUser u
				where
					u.user_id = ? and
					u.position_id = pg.position_id and
					pg.group_id = gop.group_id and
					gop.action = 'DebtManSort_' || csort.cust_code
			)) and
			d.cust_id = cust.cust_id and
			d.debt_state_id = s.debt_state_id and
			d.cust_id = ac.cust_id and
			d.cust_id = cr.cust_id and
			cdd.cust_id = d.cust_id and
			cdd.stmt_id = r.stmt_id and
			s.debt_state_id in ($debt_state_ids)
			$where_acct
			$where_debt_state
			$where_diary_status
			$where_review_date
			$where_csort
	}]

	if {[catch {
		set stmt    [inf_prep_sql $DB $query_debt_diary]
		set sel_rs  [inf_exec_stmt $stmt $USERID $USERID $USERID]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		err_bind "Unable to execute query : $msg"
		bind_csort
		asPlayFile -nocache debt_man_arg.html
	}

	set nrows [db_get_nrows $sel_rs]
	catch {unset DEBT_MAN}
	if { $nrows > 0 } {
		for {set i 0} {$i < $nrows} {incr i} {
			set cust_id [db_get_col $sel_rs $i cust_id]
			set DEBT_MAN($i,cust_id)\
			 $cust_id
			set DEBT_MAN($i,fname)\
			 [db_get_col $sel_rs $i fname]
			set DEBT_MAN($i,lname)\
			 [db_get_col $sel_rs $i lname]
			set DEBT_MAN($i,cr_date)\
			 [db_get_col $sel_rs $i cr_date]
			set DEBT_MAN($i,review_date)\
			 [db_get_col $sel_rs $i review_date]
			set DEBT_MAN($i,reviewed_at)\
			 [db_get_col $sel_rs $i reviewed_at]
			set DEBT_MAN($i,username)\
			 [db_get_col $sel_rs $i username]
			set DEBT_MAN($i,code)\
			 [db_get_col $sel_rs $i code]
			set DEBT_MAN($i,description)\
			 [db_get_col $sel_rs $i description]
			set debt_state\
			 [db_get_col $sel_rs $i debt_state_id]
			set DEBT_MAN($i,debt_state_id)\
			 $debt_state
			set DEBT_MAN($i,oper_id)\
			 [db_get_col $sel_rs $i oper_id]
			set DEBT_MAN($i,status)\
			 [db_get_col $sel_rs $i status]
			set DEBT_MAN($i,notes)\
			 [db_get_col $sel_rs $i notes]
			set DEBT_MAN($i,letter_sent)\
			 [db_get_col $sel_rs $i letter_sent]
			set DEBT_MAN($i,next_state_id)\
			 [db_get_col $sel_rs $i next_debt_state_id]
			set DEBT_MAN($i,debt_diary_id)\
			 [db_get_col $sel_rs $i debt_diary_id]
			set DEBT_MAN($i,acct_no)\
			 [db_get_col $sel_rs $i acct_no]
			set DEBT_MAN($i,opened)\
			 [db_get_col $sel_rs $i opened]
			set DEBT_MAN($i,balance)\
			 [db_get_col $sel_rs $i balance]
			set DEBT_MAN($i,lp_date)\
			 [db_get_col $sel_rs $i last_payment_date]
			set DEBT_MAN($i,lp_amount)\
			 [db_get_col $sel_rs $i last_payment_amount]
			set DEBT_MAN($i,max_bet)\
			 [db_get_col $sel_rs $i max_bet_stake]
			set DEBT_MAN($i,st_balance)\
			 [db_get_col $sel_rs $i st_balance]
			set DEBT_MAN($i,stmt_id)\
			 [db_get_col $sel_rs $i stmt_id]
			set DEBT_MAN($i,largest_payment)\
			 [db_get_col $sel_rs $i largest_payment]
			set DEBT_MAN($i,count_oad)\
			 [db_get_col $sel_rs $i count_oad]
			set DEBT_MAN($i,count_ledger)\
			 [db_get_col $sel_rs $i count_ledger]
			set DEBT_MAN($i,cust_group)\
			 [db_get_col $sel_rs $i cust_group]
		}

		tpBindString state_code  $DEBT_MAN(0,code)
		tpBindString state_desc  $DEBT_MAN(0,description)
	}
	catch {db_close $sel_rs}

	tpSetVar debt_num_rows $nrows

	tpBindVar lname          DEBT_MAN   lname         row_idx
	tpBindVar fname          DEBT_MAN   fname         row_idx
	tpBindVar cust_id        DEBT_MAN   cust_id       row_idx
	tpBindVar cr_date        DEBT_MAN   cr_date       row_idx
	tpBindVar review_date    DEBT_MAN   review_date   row_idx
	tpBindVar reviewed_at    DEBT_MAN   reviewed_at   row_idx
	tpBindVar username       DEBT_MAN   username      row_idx
	tpBindVar code           DEBT_MAN   code          row_idx
	tpBindVar description    DEBT_MAN   description   row_idx
	tpBindVar debt_state_id  DEBT_MAN   debt_state_id row_idx
	tpBindVar oper_id        DEBT_MAN   oper_id       row_idx
	tpBindVar status         DEBT_MAN   status        row_idx
	tpBindVar notes          DEBT_MAN   notes         row_idx
	tpBindVar debt_diary_id  DEBT_MAN   debt_diary_id row_idx
	tpBindVar next_state_id  DEBT_MAN   next_state_id row_idx
	tpBindVar letter_sent    DEBT_MAN   letter_sent   row_idx
	tpBindVar acct_no        DEBT_MAN   acct_no       row_idx
	tpBindVar opened         DEBT_MAN   opened        row_idx
	tpBindVar balance        DEBT_MAN   balance       row_idx
	tpBindVar lp_date        DEBT_MAN   lp_date       row_idx
	tpBindVar lp_amount      DEBT_MAN   lp_amount     row_idx
	tpBindVar max_bet        DEBT_MAN   max_bet       row_idx
	tpBindVar st_balance     DEBT_MAN   st_balance    row_idx
	tpBindVar stmt_id        DEBT_MAN   stmt_id       row_idx
	tpBindVar largest_payment DEBT_MAN  largest_payment row_idx
    tpBindVar count_oad      DEBT_MAN   count_oad     row_idx
	tpBindVar count_ledger   DEBT_MAN   count_ledger  row_idx
	tpBindVar cust_group     DEBT_MAN   cust_group    row_idx

	# pass the arguments
	tpBindString DebtState   $debt_state
	tpBindString DiaryStatus $diary_status
	tpBindString ReviewDate  $review_date
	tpBindString csort       $csort
	tpBindString AcctNo      $acct_no

	if {![OT_CfgGet RIGHTNOW_DEBT_MAN_ENABLED 1]} {
		# bind up letter templates & letters
		get_letters $debt_state
	}

	asPlayFile -nocache debt_man.html
}



#
# ----------------------------------------------------------------------------
# Do a debt management action
# ----------------------------------------------------------------------------
#
proc do_debt_man args {

	set act [reqGetArg SubmitName]

	set debt_state   [reqGetArg DebtState]
	set diary_status [reqGetArg DiaryStatus]
	set review_date  [reqGetArg ReviewDate]

	if {$act == "MoveToNextState"} {
		change_states
		go_debt_man
	} elseif {$act == "RemoveFromDebtMan"} {
		remove_from_debt_man
		go_debt_man
	} elseif {$act == "AddNote"} {
		do_add_note
		return
	} elseif {![OT_CfgGet RIGHTNOW_DEBT_MAN_ENABLED 1] \
				&& $act == "SendLetter"} {
		send_letters 1
		go_debt_man
	} elseif {$act == "AuditHistory"} {
		reqSetArg BackAction GoDebtMan
		ADMIN::AUDIT::go_audit
	} elseif {$act == "ChangeReviewDate"} {
		change_review_dates $debt_state
		go_debt_man
	} elseif {$act == "Back"} {
		reqSetArg SubmitName ""
		go_debt_man
	} else {
		error "unexpected debt management operation SubmitName: $act"
	}
}



#
# ----------------------------------------------------------------------------
# Send letter to customer
# ----------------------------------------------------------------------------
#
proc send_letter {cust_id letter_id {debt_diary_id -1}} {
	
	ob::log::write INFO {==> send_letter}

	global DB

	ADMIN::AUTO_LETTERS::add_cust_letter $cust_id $letter_id

	if {$debt_diary_id > -1 } {
		set update_letter_sent [subst {
			update
				tDebtDiary
			set
				letter_sent = 'Y'
			where
				debt_diary_id = ?
		}]

		if {[catch {
			set stmt       [inf_prep_sql $DB $update_letter_sent $debt_diary_id]
			inf_exec_stmt  $stmt
			inf_close_stmt $stmt
		} msg]} {
			ob::log::write ERROR {unable to update debt diary : $msg}
			err_bind "Unable to update debt diary : $msg"
			return -1
		}
	}
	return 1
}



#
# ----------------------------------------------------------------------------
# Send letters to selected customers
# ----------------------------------------------------------------------------
#
proc send_letters { {allow_new 0} } {

	ob::log::write INFO {==> send_letters}

	global DB

	set cust_id_list [reqGetArgs sc]
	set letter_id    [reqGetArg Letter]
	set template_id  [reqGetArg LetterTemplate]

	if { [llength $cust_id_list] == 0} {
		err_bind "No customer selected"
		return
	}

	if {$letter_id == 0} {
		if {$allow_new!=1} {
			err_bind "Create a letter first"
		} else {
			set letter_id [create_letter $template_id]
			if {$letter_id == -1} {
				err_bind "Error creating a new letter"
				return
			}
		}
	}

	set debt_diary_ids [list]

	foreach cust_id $cust_id_list {
		lappend debt_diary_ids [reqGetArg DIARY_$cust_id]
		ADMIN::AUTO_LETTERS::add_cust_letter $cust_id $letter_id
	}

	set diary_ids [join $debt_diary_ids ,]

	set update_letter_sent [subst {
		update
			tDebtDiary
		set
			letter_sent = 'Y'
		where
			debt_diary_id in ($diary_ids)
	}]

	if {[catch {
		set stmt    [inf_prep_sql $DB $update_letter_sent]
		inf_exec_stmt  $stmt
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to update debt diary : $msg}
		err_bind "Unable to update debt diary : $msg"
	} else {
		msg_bind "Letters succesfully sent"
	}

}



#
# ----------------------------------------------------------------------------
# Bind debt states allowed for this user
# ----------------------------------------------------------------------------
#
proc bind_allowed_states {} {
	global DEBT_MAN

	set allowed_debt_states [get_allowed_states]

	set num_states 0
	foreach {debt_state_id debt_code} $allowed_debt_states {
		set DEBT_MAN($num_states,debt_code)   $debt_code
		set DEBT_MAN($num_states,debt_state_id) $debt_state_id
		incr num_states
	}

	tpSetVar debt_num_states $num_states

	tpBindVar debt_code    DEBT_MAN debt_code      row_idx
	tpBindVar state_id     DEBT_MAN debt_state_id  row_idx

}



#
# ----------------------------------------------------------------------------
# Bind up customer group names and sorts
# ----------------------------------------------------------------------------
#
proc bind_csort {} {

	global DEBT_CSORT DB
	set sql {
		select
			cust_code,
			desc
		from
			tCustCode
	}

	if {[catch {
		set stmt    [inf_prep_sql $DB $sql]
		set sel_rs  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		err_bind "Unable to execute query : $msg"
		return
	}

	set nrows [db_get_nrows $sel_rs]
	catch {unset DEBT_CSORT}
	if {$nrows > 0} {
		for {set i 0} {$i < $nrows} {incr i} {
			set DEBT_CSORT($i,code)\
				[db_get_col $sel_rs $i cust_code]
			set DEBT_CSORT($i,desc)\
				[db_get_col $sel_rs $i desc]
		}
	}

	tpSetVar csort_num_rows $nrows

	tpBindVar sort           DEBT_CSORT  code         csort_idx
	tpBindVar desc           DEBT_CSORT  desc         csort_idx

	catch {db_close $sel_rs}

}



#
# ----------------------------------------------------------------------------
# Display debt management selection filter screen
# ----------------------------------------------------------------------------
#
proc go_debt_man_sel_arg {} {

	bind_csort
	asPlayFile -nocache debt_man_sel_arg.html
}



#
# ----------------------------------------------------------------------------
# Display debt management selection screen
# ----------------------------------------------------------------------------
#
proc go_debt_man_sel {} {

	ob::log::write INFO {==> go_debt_man_sel}

	global DB USERID
	global USERNAME
	global DEBT_MAN

	set csort         [reqGetArg csort]
	set StatementDate [reqGetArg StatementDate]

	set where_csort    ""
	set csort_outer    "outer"
	if {$csort != ""} {
		set where_csort "and csort.cust_code = '$csort'"
		set csort_outer ""
	}
	set where_st_date ""
	if {$StatementDate != ""} {
		set where_st_date "and r.cr_date between '$StatementDate 00:00:00' and '$StatementDate 23:59:59'"
	}

	# column filters
	set fQuery ""
	set filter [reqGetArg filter]
	set filterFields [list fUsername\
							fAcctNo\
							fOpenedFrom\
							fOpenedTo\
							fCurrBalHigher\
							fCurrBalLower\
							fStBalHigher\
							fStBalLower\
							fLedgerHigher\
							fLedgerLower\
							fOadHigher\
							fOadLower\
							fRunnBalHigher\
							fRunnBalLower]
	if {$filter == "1"} {

		foreach {fieldName} $filterFields {
			set value [reqGetArg $fieldName]
			# bind fields back to populate the form again
			tpBindString $fieldName $value
			if {$value == ""} {
				continue
			}

			switch -exact -- $fieldName {
				fUsername {
					append fQuery "and cust.username = '$value'"
				}
				fAcctNo   {
					append fQuery "and cust.acct_no = '$value'"
				}
				fOpenedFrom {
					append fQuery "and cust.cr_date > '$value 00:00:00'"
				}
				fOpenedTo   {
					append fQuery "and cust.cr_date < '$value 23:59:59'"
				}
				fCurrBalHigher {
					append fQuery "and ac.balance >= $value"
				}
				fCurrBalLower {
					append fQuery "and ac.balance <= $value"
				}
				fStBalHigher {
					append fQuery "and r.pmt_amount >= $value"
				}
				fStBalLower {
					append fQuery "and r.pmt_amount <= $value"
				}
				fLedgerHigher {
					append fQuery "and (cdd.legacy_count_ledger + cdd.count_ledger) >= $value"
				}
				fLedgerLower {
					append fQuery "and (cdd.legacy_count_ledger + cdd.count_ledger) <= $value"
				}
				fOadHigher {
					append fQuery "and (cdd.legacy_count_oad + cdd.count_oad) >= $value"
				}
				fOadLower {
					append fQuery "and (cdd.legacy_count_oad + cdd.count_oad) <= $value"
				}
				fRunnBalHigher {
					append fQuery "and cdd.running_balance >= $value"
				}
				fRunnBalLower {
					append fQuery "and cdd.running_balance <= $value"
				}
			}
		}
	} else {
		foreach {fieldName} $filterFields {
			tpBindString $fieldName ""
		}
	}

	set sql [subst {
		select
			cust.username,
			cust.cust_id,
			cr.fname,
			cr.mname,
			cr.lname,
			EXTEND(cust.cr_date, YEAR to DAY) as cust_reg_date,
			ac.cr_date,
			(ac.balance + ac.sum_ap) as balance,
			cust.acct_no,
			debt.status,
			cdd.debt_paid,
			debt.cust_debt_id,
			debt.debt_run_id,
			EXTEND(cdd.last_payment_date, YEAR to DAY) as last_payment_date,
			cdd.last_payment_amount,
			cr.code,
			cdd.max_bet_stake,
			debt.stmt_id,
			r.pmt_amount as st_balance,
			cdd.largest_payment,
			csort.desc as cust_group,
			cdd.count_arrears,
			(cdd.legacy_count_ledger + cdd.count_ledger) as count_ledger,
			(cdd.legacy_count_oad + cdd.count_oad) as count_oad,
			cdd.running_balance
		from
			tCustomerDebt debt,
			tAcct ac,
			tCustomer cust,
			tCustomerReg cr,
			tStmtRecord r,
			tCustDebtData cdd,
			$csort_outer tCustCode csort
		where
			cr.code = csort.cust_code and
			(exists (
				select 1
				from
					tAdminUserOp uo
				where
					uo.user_id = ?
				and
					uo.action = 'DebtManSort_' || csort.cust_code
			) or exists (
				select 1
				from
					tAdminUserGroup ug,
					tAdminGroupOp gop
				where
					ug.user_id = ? and
					ug.group_id = gop.group_id and
					gop.action = 'DebtManSort_' || csort.cust_code
			) or exists (
				select 1
				from
					tAdminPosnGroup pg,
					tAdminGroupOp gop,
					tAdminUser u
				where
					u.user_id = ? and
					u.position_id = pg.position_id and
					pg.group_id = gop.group_id and
					gop.action = 'DebtManSort_' || csort.cust_code
			)) and
			debt.cust_id = cust.cust_id and
			debt.cust_id = cr.cust_id and
			debt.cust_id = ac.cust_id and
			debt.stmt_id = r.stmt_id and
			debt.cust_id = cr.cust_id and
			debt.cust_id = cdd.cust_id and
			debt.status = 'P'
			$where_csort
			$where_st_date
			$fQuery
		order by
			debt.cust_debt_id asc
	}]

	if {[catch {
		set stmt    [inf_prep_sql $DB $sql]
		set sel_rs  [inf_exec_stmt $stmt $USERID $USERID $USERID]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		err_bind "Unable to execute query : $msg"
		return
	}

	set nrows [db_get_nrows $sel_rs]
	catch {unset DEBT_MAN}
	if { $nrows > 0 } {
		for {set i 0} {$i < $nrows} {incr i} {
			set cust_id [db_get_col $sel_rs $i cust_id]
			set DEBT_MAN($i,cust_id)\
				[db_get_col $sel_rs $i cust_id]
			set DEBT_MAN($i,fname)\
				[db_get_col $sel_rs $i fname]
			set DEBT_MAN($i,lname)\
				[db_get_col $sel_rs $i lname]
			set DEBT_MAN($i,username)\
				[db_get_col $sel_rs $i username]
			set DEBT_MAN($i,balance)\
				[db_get_col $sel_rs $i balance]
			set DEBT_MAN($i,status)\
				[db_get_col $sel_rs $i status]
			set DEBT_MAN($i,debt_paid)\
				[db_get_col $sel_rs $i debt_paid]
			set DEBT_MAN($i,debt_run_id)\
				[db_get_col $sel_rs $i debt_run_id]
			set DEBT_MAN($i,cust_debt_id)\
				[db_get_col $sel_rs $i cust_debt_id]
			set DEBT_MAN($i,lp_date)\
				[db_get_col $sel_rs $i last_payment_date]
			set DEBT_MAN($i,lp_amount)\
				[db_get_col $sel_rs $i last_payment_amount]
			set DEBT_MAN($i,max_bet)\
				[db_get_col $sel_rs $i max_bet_stake]
			set DEBT_MAN($i,cust_reg_date)\
				[db_get_col $sel_rs $i cust_reg_date]
			set DEBT_MAN($i,acct_no)\
				[db_get_col $sel_rs $i acct_no]
			set DEBT_MAN($i,count_ca)\
				[db_get_col $sel_rs $i count_arrears]
			set DEBT_MAN($i,count_ledger)\
				[db_get_col $sel_rs $i count_ledger]
			set DEBT_MAN($i,stmt_id)\
				[db_get_col $sel_rs $i stmt_id]
			set DEBT_MAN($i,st_balance)\
				[db_get_col $sel_rs $i st_balance]
			set DEBT_MAN($i,largest_payment)\
				[db_get_col $sel_rs $i largest_payment]
			set DEBT_MAN($i,cust_group)\
				[db_get_col $sel_rs $i cust_group]
			set DEBT_MAN($i,count_oad)\
				[db_get_col $sel_rs $i count_oad]
			set DEBT_MAN($i,running_balance)\
				[db_get_col $sel_rs $i running_balance]
		}
	}

	tpSetVar debt_num_rows $nrows

	tpBindString csort $csort
	tpBindString StatementDate $StatementDate

	tpBindVar lname           DEBT_MAN       lname         row_idx
	tpBindVar fname           DEBT_MAN       fname         row_idx
	tpBindVar cust_id         DEBT_MAN       cust_id       row_idx
	tpBindVar username        DEBT_MAN       username      row_idx
	tpBindVar balance         DEBT_MAN       balance       row_idx
	tpBindVar status          DEBT_MAN       status        row_idx
	tpBindVar debt_paid       DEBT_MAN       debt_paid     row_idx
	tpBindVar cust_debt_id    DEBT_MAN       cust_debt_id  row_idx
	tpBindVar lp_date         DEBT_MAN       lp_date       row_idx
	tpBindVar lp_amount       DEBT_MAN       lp_amount     row_idx
	tpBindVar max_bet         DEBT_MAN       max_bet       row_idx
	tpBindVar cust_reg_date   DEBT_MAN       cust_reg_date row_idx
	tpBindVar acct_no         DEBT_MAN       acct_no       row_idx
	tpBindVar count_ca        DEBT_MAN       count_ca      row_idx
	tpBindVar count_ledger    DEBT_MAN       count_ledger  row_idx
	tpBindVar stmt_id         DEBT_MAN       stmt_id       row_idx
	tpBindVar st_balance      DEBT_MAN       st_balance    row_idx
	tpBindVar largest_payment DEBT_MAN       largest_payment row_idx
	tpBindVar cust_group      DEBT_MAN       cust_group    row_idx
	tpBindVar count_oad       DEBT_MAN       count_oad     row_idx
	tpBindVar running_balance DEBT_MAN       running_balance row_idx

	catch {db_close $sel_rs}

	get_letters 1

	asPlayFile -nocache debt_man_sel.html
}



#
# ----------------------------------------------------------------------------
# Do a debt management selection
# ----------------------------------------------------------------------------
#
proc do_debt_man_sel args {

	set act [reqGetArg SubmitName]

	if {$act == "MoveToDebtDiary"} {
		move_to_debt_diary
		go_debt_man_sel
	} elseif {$act == "RemoveFromDebtManSel"} {
		remove_from_debt_man_sel
		go_debt_man_sel
	} elseif {$act == "AuditHistory"} {
		reqSetArg BackAction GoDebtManSel
		ADMIN::AUDIT::go_audit
	} elseif {$act == "Back"} {
		go_debt_man_sel_arg
	} else {
		error "unexpected debt management operation SubmitName: $act"
		go_debt_man_sel
	}

}



#
# ----------------------------------------------------------------------------
# Remove selected customers from the debt management process
# ----------------------------------------------------------------------------
#
proc remove_from_debt_man args {

	ob::log::write INFO {==> remove_from_debt_man}

	set cust_id_list [reqGetArgs sc]

	if { [llength $cust_id_list] == 0} {
		return
	}

	# set the 'Suspend' status in tDebtDiary
	# remove status flag, if any
	foreach cust_id $cust_id_list {

		set debt_diary_id [reqGetArg DIARY_$cust_id]
		set debt_state_id [reqGetArg ST_$cust_id]
		set result [change_state $cust_id\
								 $debt_diary_id\
								 $debt_state_id\
								 0\
								 1\
								 -1]
		if {$result < 1} {
			return
		}
	}

	msg_bind "Status succesfully updated"

}

#
# ----------------------------------------------------------------------------
# Remove selected customers from the debt management selection process
# ----------------------------------------------------------------------------
#
proc remove_from_debt_man_sel args {

	ob::log::write INFO {==> remove_from_debt_man_sel}

	set cust_id_list [reqGetArgs sc]

	if { [llength $cust_id_list] == 0} {
		return
	}

	# set the 'ignore' status (X) in tCustomerDebt
	foreach cust_id $cust_id_list {

		set cust_debt_id [reqGetArg cid_$cust_id]

		set result [change_cust_debt $cust_debt_id "X"]

		if {$result < 0 } {
			set msg "Unable to change customer debt status:\
				cust_debt_id: $cust_debt_id\
				cust_id $cust_id "
			ob::log::write ERROR $msg
			err_bind $msg
			return
		}
	}

	msg_bind "Status succesfully updated"

}



#
# ----------------------------------------------------------------------------
# Change customer's status in tCustomerDebt
# ----------------------------------------------------------------------------
#
proc change_cust_debt {cust_debt_id status} {

	global DB USERID

	set change_status {
		update
			tCustomerDebt
		set
			status = ?,
			oper_id = ?
		where
			cust_debt_id = ?
	}

	if {[catch {
		set stmt [inf_prep_sql $DB $change_status]
		inf_exec_stmt $stmt $status $USERID $cust_debt_id
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR $msg
		return -1
	}

	return 1
}

#
# ----------------------------------------------------------------------------
# Get debt state code from state id
# ----------------------------------------------------------------------------
#

proc get_state_code {state_id} {

	global DB

	set get_code {
		select
			code
		from
			tDebtState
		where
			debt_state_id = ?
	}

	if {[catch {
		set stmt    [inf_prep_sql $DB $get_code]
		set sel_rs  [inf_exec_stmt $stmt $state_id]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		return -1
	}

	if {[db_get_nrows $sel_rs] != 1} {
		return -1
	}

	set state_code [db_get_col $sel_rs 0 code]

	catch {db_close $sel_rs}

	return $state_code

}

#
# ----------------------------------------------------------------------------
# Get debt state id from state code
# ----------------------------------------------------------------------------
#
proc get_state_id {state_code} {

	global DB

	set get_state {
		select
			debt_state_id
		from
			tDebtState
		where
			code = ?
	}

	if {[catch {
		set stmt	[inf_prep_sql $DB $get_state]
		set sel_rs	[inf_exec_stmt $stmt $state_code]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		return -1
	}

	if {[db_get_nrows $sel_rs] != 1} {
		return -1
	}

	set state_id [db_get_col $sel_rs 0 debt_state_id]

	catch {db_close $sel_rs}

	return $state_id

}



#
# ----------------------------------------------------------------------------
# Move selected customers from tCustomerDebt to tDebtDiary
# ----------------------------------------------------------------------------
#
proc move_to_debt_diary args {

	ob::log::write INFO {==> move_to_debt_diary}

	global DB

	set cust_id_list [reqGetArgs sc]
	set letter_id    [reqGetArg  Letter]
	set review_date  [reqGetArg  NewReviewDate]
	if {$letter_id == 0} {
		err_bind "Select an existing letter first"
		return
	}

	if { [llength $cust_id_list] == 0} {
		return
	}

	if {$review_date == ""} {
		set review_date -1
	}

	set next_state_id 2

	foreach cust_id $cust_id_list {

		set cust_debt_id [reqGetArg cid_$cust_id]

		set result [change_state $cust_id\
								 0\
								 $next_state_id\
								 1\
								 0\
								 $letter_id\
								 $review_date]

		if {$result != 1} {
			return
		}

		set result [change_cust_debt $cust_debt_id "C"]

		if {$result != 1} {
			set msg "Unable to change customer status:\
				cust_id: $cust_id\
				cust_debt_id: $cust_debt_id "
			ob::log::write ERROR $msg
			err_bind $msg
			return
		}

	}

	msg_bind "Status succesfully updated"
}



#
# ----------------------------------------------------------------------------
# Change states for selected customers
# ----------------------------------------------------------------------------
#
proc change_states {} {

	ob::log::write INFO {==> change_states}

	set cust_id_list [reqGetArgs sc]
	if {![OT_CfgGet RIGHTNOW_DEBT_MAN_ENABLED 1]} {
		set letter_id    [reqGetArg  Letter]
		set review_date  [reqGetArg NewReviewDate]

		if {$letter_id == "" || $letter_id == 0} {
			err_bind "Select a letter first"
			return
		}
	}

	if {[llength $cust_id_list] == 0} {
		return
	}

	if {$review_date == ""} {
		set review_date -1
	}

	# TODO since next_state_id will be the same for everyone in this foreach,
	# could we speed things up by reading only once from tDebtState?

	foreach cust_id $cust_id_list {

		set debt_diary_id [reqGetArg DIARY_$cust_id]
		set next_state_id [reqGetArg NEXT_$cust_id]

		if {[OT_CfgGet RIGHTNOW_DEBT_MAN_ENABLED 1]} {
			set result [move_state \
						$cust_id\
						$debt_diary_id]
		} else {
			set result [change_state $cust_id\
								 $debt_diary_id\
								 $next_state_id\
								 0\
								 0\
								 $letter_id\
								 $review_date]
		}
		if {$result != 1}  {
			err_bind "Failed to change account debt status"
			return
		}
	}

	msg_bind "Status succesfully updated"
}

# ----------------------------------------------------------------------------
# Move state
# ----------------------------------------------------------------------------
# Try to move the customer's debt state to that set by the
# MoveToDebtState flag
#

proc move_state { cust_id debt_diary_id } {

	ob::log::write INFO {==> move_state $cust_id $debt_diary_id}

	global DB USERID USERNAME

	if {[check_cust_unique $cust_id $debt_diary_id] == 0} {
		# fail
		set msg  "Customer has an active debt diary entry"
		err_bind $msg
		ob::log::write ERROR $msg
		return
	}

	set get_move {
		select
			ds.add_flag,
			ds.debt_state_id,
			ds.suspend_account
		from
			tDebtState ds,
			tCustomerFlag cf
		where
			cf.cust_id = ? and
			cf.flag_name = 'MoveToDebtState' and
			cf.flag_value in ('DS1','DS2','DS3','DS4','DS5','DSPP') and
			ds.code = cf.flag_value
	}

	if {[catch {
		set stmt    [inf_prep_sql $DB $get_move]
		set sel_rs  [inf_exec_stmt $stmt $cust_id]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		return -1
	}

	if {[db_get_nrows $sel_rs] != 1} {
		catch {db_close $sel_rs}
		return -1
	}

	set add_flag            [db_get_col $sel_rs 0 add_flag]
	set debt_state_id       [db_get_col $sel_rs 0 debt_state_id]
	set suspend_account     [db_get_col $sel_rs 0 suspend_account]

	catch {db_close $sel_rs}

	set move_debt_state {
		execute procedure pDebtMoveStateCust (
				p_oper_id = ?,
				p_admin_user = ?,
				p_cust_id = ?,
				p_next_flag = ?,
				p_next_state_id = ?,
				p_suspend_account = ?,
				p_transactional = 'N'
		)
	}

	inf_begin_tran $DB

	if {[catch {
		set stmt    [inf_prep_sql $DB $move_debt_state]
		set sel_rs  [inf_exec_stmt \
						 $stmt \
						 $USERID \
						 $USERNAME \
						 $cust_id \
						 $add_flag \
						 $debt_state_id \
						 $suspend_account]
		inf_close_stmt $stmt
	} msg]} {
		inf_rollback_tran $DB
		ob::log::write ERROR {unable to execute query : $msg}
		return -1
	}

	catch {db_close $sel_rs}

	set remove_cust_flag {
		delete from
		    tCustomerFlag
		where
		    cust_id = ? and flag_name = 'MoveToDebtState'
	}

	if {[catch {
		set stmt    [inf_prep_sql $DB $remove_cust_flag]
		set sel_rs  [inf_exec_stmt $stmt $cust_id]
		inf_close_stmt $stmt
	} msg]} {
		inf_rollback_tran $DB
		ob::log::write ERROR {unable to execute query : $msg}
		return -1
	}

	inf_commit_tran $DB

	return 1

}

#
# ----------------------------------------------------------------------------
# Change state
# ----------------------------------------------------------------------------
# change only: no previous state, don't attempt to change previous
#       debt diary entry (default 0)
# remove: no new diary entry, only change current status
#       in this case, state_id is current rather than the next state
#       (default 0)
# ----------------------------------------------------------------------------
#
proc change_state { cust_id\
					debt_diary_id\
					state_id\
					change_only\
					remove\
					letter_id\
					{review_date -1} } {

	ob::log::write INFO {==> change_state}

	global DB USERID

	if {[check_cust_unique $cust_id $debt_diary_id] == 0} {
		# fail
		set msg  "Customer has an active debt diary entry"
		err_bind $msg
		ob::log::write ERROR $msg
		return
	}

	# debt diary. status: (A) before review / (R) reviewed / (S) suspended

	set get_state {
		select
			debt_state_id,
			code,
			description,
			action,
			next_debt_state_id,
			remove_flag,
			add_flag,
			incr_review,
			suspend_account
		from
			tDebtState
		where
			debt_state_id = ?
	}

	if {[catch {
		set stmt    [inf_prep_sql $DB $get_state]
		set sel_rs  [inf_exec_stmt $stmt $state_id]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		return -1
	}

	if {[db_get_nrows $sel_rs] != 1} {
		return -1
	}

	set remove_flag     [db_get_col $sel_rs 0 remove_flag]
	set add_flag        [db_get_col $sel_rs 0 add_flag]
	set incr_review     [db_get_col $sel_rs 0 incr_review]
	set suspend_account [db_get_col $sel_rs 0 suspend_account]

	catch {db_close $sel_rs}

	set get_remove_flag {
		select
		    ds.remove_flag
		from
		    tDebtState ds,
		    tDebtDiary dd
		where
		    dd.debt_diary_id = ? and
		    ds.debt_state_id = dd.debt_state_id
	}

	if {[catch {
		set stmt    [inf_prep_sql $DB $get_remove_flag]
		set sel_rs  [inf_exec_stmt $stmt $debt_diary_id]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		return -1
	}

	if {[db_get_nrows $sel_rs] != 1} {
		set remove_flag {}
	} else {
		set remove_flag [db_get_col $sel_rs 0 remove_flag]
	}

	catch {db_close $sel_rs}

	inf_begin_tran $DB

	# un/suspend the customer if needed
	set result [upd_cust_status $cust_id $suspend_account]
	if {$result != 1} {
		inf_rollback_tran $DB
		return
	}

	if {[OT_CfgGet RIGHTNOW_DEBT_MAN_ENABLED 1]} {
		# 'send' the letter
		if {$letter_id != -1} {
			set result [send_letter $cust_id $letter_id]
			if {$result != 1} {
				inf_rollback_tran $DB
				set msg  "Error sending a letter"
				err_bind $msg
				ob::log::write ERROR $msg
				return
			}
		}
	}

	# add&remove customer status flags, if any
	if {$remove==1} {
		remove_cust_flag $cust_id $remove_flag "N" 1
	} elseif {$remove_flag !=""} {
		remove_cust_flag $cust_id $remove_flag "N"
	}

	if {$remove != 1} {

		if { $add_flag != ""} {
			add_cust_flag $cust_id $add_flag "N"
		}

		# set new review date at (today + incr_review)
		if {$review_date == "-1"} {
			set review_date [clock format [clock scan "+$incr_review days"\
					-base [clock seconds]] -format {%Y-%m-%d}]
		}
		# insert a new debt diary entry
		set result [ins_debt_diary $cust_id "A" $review_date $state_id]
		if {$result != 1} {
			inf_rollback_tran $DB
			set msg "Unable to insert into tDebtDiary
				cust_id: $cust_id"
			ob::log::write ERROR $msg
			err_bind $msg
			return -1
		}
	}

	if { $change_only != 1} {
		set update_debt_diary {
			update
				tDebtDiary
			set
				oper_id = ?,
				status  = ?,
				reviewed_at = CURRENT
			where
				cust_id = ? and
				debt_diary_id = ?
		}

		if { $remove == 1} {
			set status "S"
		} else {
			set status "R"
		}

		if {[catch {
			set stmt    [inf_prep_sql $DB $update_debt_diary]
			set sel_rs  [inf_exec_stmt $stmt $USERID $status\
													$cust_id\
													$debt_diary_id]
			inf_close_stmt $stmt
		} msg]} {
			inf_rollback_tran $DB
			set msg "Unable to change customer status:\
					debt diary update failed -\
					cust_id $cust_id"
			ob::log::write ERROR $msg
			err_bind $msg
			return -1
		}
	}

	inf_commit_tran $DB

	return 1

}



#
# ----------------------------------------------------------------------------
# Remove a customer status flag
# ----------------------------------------------------------------------------
#
proc remove_cust_flag {cust_id flag_name {transactional "Y"} {remove 0}} {

	ob::log::write INFO {==> remove_cust_flag}
	
	global DB USERID

	if {$remove==1} {
		# remove all flags
		set flag_clause "status_flag_tag like 'DEBTST%' and"
	} else {
		set flag_clause "status_flag_tag = '$flag_name' and"
	}

	set get_flag [subst {
		select
			cust_flag_id
		from
			tCustStatusFlag
		where
			cust_id = ? and
			$flag_clause
			status = 'A';
	}]

	if {[catch {
		set stmt    [inf_prep_sql $DB $get_flag]
		set sel_rs  [inf_exec_stmt $stmt $cust_id]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		return 0
	}

	set nrows [db_get_nrows $sel_rs]
	if {$nrows == 0} {
		# don't worry if no status flag found
		return 1
	}

	set remove_flag {
		execute procedure pDelCustStatusFlag
		(
			p_cust_flag_id = ?,
			p_user_id = ?,
			p_transactional = ?
		)
	}

	for {set i 0} {$i < $nrows} {incr i} {
		set cust_flag_id [db_get_col $sel_rs 0 cust_flag_id]
		if {[catch {
			set stmt    [inf_prep_sql $DB $remove_flag]
			inf_exec_stmt $stmt $cust_flag_id $USERID $transactional
			inf_close_stmt $stmt
		} msg]} {
			ob::log::write ERROR {unable to execute query : $msg}
			return -1
		}

	}
	catch {db_close $sel_rs}

	return 1
}



#
# ----------------------------------------------------------------------------
# Add a customer status flag
# ----------------------------------------------------------------------------
#
proc add_cust_flag {cust_id flag_name {transactional "Y"}} {

	global DB USERID

	set ins_flag {
		execute procedure pInsCustStatusFlag
		(
			p_cust_id = ?,
			p_status_flag_tag = ?,
			p_user_id = ?,
			p_reason = ?,
			p_transactional = ?
		)
	}

	if {[catch {
		set stmt    [inf_prep_sql $DB $ins_flag]
		inf_exec_stmt $stmt\
					$cust_id\
					$flag_name\
					$USERID "Account flagged by debt management"\
					$transactional
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		return -1
	}

	return 1
}



#
# ----------------------------------------------------------------------------
# Insert a new record to debt diary
# ----------------------------------------------------------------------------
#
proc ins_debt_diary {   cust_id\
						status\
						review_date\
						debt_state_id} {

	global DB USERID

	set ins_debt_diary {
		execute procedure pInsDebtDiary (
			p_oper_id = ?,
			p_cust_id = ?,
			p_status = ?,
			p_review_date = ?,
			p_debt_state_id = ?
		)
	}

	if {[catch {
		set stmt	[inf_prep_sql $DB $ins_debt_diary]
		inf_exec_stmt $stmt $USERID\
				$cust_id\
				$status\
				$review_date\
				$debt_state_id
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		return -1
	}

	return 1
}



#
# ----------------------------------------------------------------------------
# Insert a new record to debt diary
# ----------------------------------------------------------------------------
#
proc ins_cust_debt_data {   cust_id\
							notes\
							balance} {

	global DB USERID

	set ins_cust_debt_data {
		insert into tCustDebtData (
			cust_id,
			is_manual_entry,
			balance,
			notes
		)
		values (
			?,
			'Y',
			?,
			?
		);
	}

	if {[catch {
		set stmt [inf_prep_sql $DB $ins_cust_debt_data]
		inf_exec_stmt $stmt\
				$cust_id\
				$balance\
				$notes
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		return -1
	}

	return 1
}



#
# ----------------------------------------------------------------------------
# Get allowed states
# - which debt states are allowed to be accessed by current user
# ----------------------------------------------------------------------------
#
proc get_allowed_states { {ids_only 0} } {

	global DB

	set get_available_states {
		select
			debt_state_id,
			code,
			description,
			action
		from
			tDebtState d
		where
			debt_state_id > 1
		order by
			debt_state_id
	}

	if {[catch {
		set stmt    [inf_prep_sql $DB $get_available_states]
		set sel_rs  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		return [list]
	}

	set ret [list]
	set nrows [db_get_nrows $sel_rs]
	if { $nrows > 0 } {
		for {set i 0} {$i < $nrows} {incr i} {
			set action [db_get_col $sel_rs $i action]
			if {[op_allowed $action]} {
				lappend ret [db_get_col $sel_rs $i debt_state_id]
				if {$ids_only == 0} {
					lappend ret [db_get_col $sel_rs\
					 $i code]
				}
			}
		}
	}
	catch {db_close $sel_rs}
	return $ret
}



#
# ----------------------------------------------------------------------------
# Update debt diary details
# ----------------------------------------------------------------------------
#
proc do_update_details args {

	set act      [reqGetArg SubmitName]
	set is_chase [reqGetArg is_chase]
	if {$act == "DoUpdateDetails"} {
		update_details
	} elseif {$act == "Back"} {
		if {$is_chase!="1"} {
			reqSetArg SubmitName ""
			go_debt_man
		} else {
			#set arguments and return to debt chase
			reqSetArg csort         [reqGetArg csort]
			reqSetArg StatementDate [reqGetArg StatementDate]
			go_debt_man_sel
		}
	} elseif {$act == "GoAudit"} {
		reqSetArg BackAction GoUpdateDetails
		ADMIN::AUDIT::go_audit
	} else {
		go_update_details
	}

}



#
# ----------------------------------------------------------------------------
# Display page for adding a note / display customer credit control stats
# ----------------------------------------------------------------------------
#
proc go_update_details {} {

	ob::log::write INFO {==> go_update_details}

	global DB

	set cust_id       [reqGetArg cust_id]
	set is_chase      [reqGetArg is_chase]
	set debt_diary_id [reqGetArg debt_diary_id]
	if {$is_chase != "1"} {
		set debt_diary_from  "tDebtDiary d,"
		set debt_diary_where " and d.debt_diary_id = $debt_diary_id \
								 and d.cust_id = cdd.cust_id"
		set debt_diary_col   ", d.debt_diary_id, d.review_date"
		tpBindString DebtState     [reqGetArg DebtState]
		tpBindString DiaryStatus   [reqGetArg DiaryStatus]
		tpBindString ReviewDate    [reqGetArg ReviewDate]
		tpBindString AcctNo        [reqGetArg AcctNo]
		tpBindString csort         [reqGetArg csort]
	} else {
		tpBindString csort         [reqGetArg csort]
		tpBindString StatementDate [reqGetArg StatementDate]
		set debt_diary_from  ""
		set debt_diary_where ""
		set debt_diary_col   ""
	}

	set get_diary_entry [subst {
		select
			cdd.notes,
			cdd.cust_id,
			cdd.count_arrears,
			(cdd.legacy_count_ledger + cdd.count_ledger) as count_ledger,
			cdd.running_balance,
			(cdd.legacy_count_oad + cdd.count_oad) as count_oad
			$debt_diary_col
		from
			$debt_diary_from
			tCustDebtData cdd
		where
			cdd.cust_id = ?
			$debt_diary_where
	}]

	if {[catch {
		set stmt    [inf_prep_sql $DB $get_diary_entry]
		set rs      [inf_exec_stmt $stmt $cust_id]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		return
	}

	foreach c [db_get_colnames $rs] {
		tpBindString $c [db_get_col $rs $c]
	}
	tpBindString is_chase $is_chase

	catch {db_close $rs}

	# 13 week summary and related data
	get_cust_stats $cust_id

	asPlayFile -nocache debt_man_note.html
}



#
# ----------------------------------------------------------------------------
# Update review date or notes for a customer
# ----------------------------------------------------------------------------
#
proc update_details {} {

	ob::log::write INFO {==> update_details}

	global DB USERID

	set cust_id [reqGetArg cust_id]
	set debt_diary_id [reqGetArg debt_diary_id]
	set review_date [reqGetArg review_date]
	set note [reqGetArg notes]

	set update_note {

		execute procedure pUpdDebtDiary (
			p_debt_diary_id = ?,
			p_oper_id       = ?,
			p_notes         = ?,
			p_review_date   = ?
		)
	}

	set c [catch {
		set stmt [inf_prep_sql $DB $update_note]
		inf_exec_stmt   $stmt\
						$debt_diary_id\
						$USERID\
						$note\
						$review_date
		inf_close_stmt $stmt
	} msg]

	if {$c} {
		err_bind "Could not update customer debt diary details: $msg"
	} else {
		msg_bind "Customer debt diary updated"
	}

	tpBindString notes          $note
	tpBindString review_date    $review_date
	tpBindString cust_id        $cust_id
	tpBindString debt_diary_id  $debt_diary_id

	go_update_details
}



#
# ----------------------------------------------------------------------------
# Configure debt states
# ----------------------------------------------------------------------------
#
proc do_cfg args {

	ob::log::write INFO {==> do_cfg}

	global DB

	set state_list [reqGetArgs select_state]

	set update_state {
		update
			tDebtState
		set
			incr_review = ?
		where
			debt_state_id = ?
	}

	foreach {state_id} $state_list {
		set incr_review [reqGetArg INCR_$state_id]

		if {[catch {
			set stmt	[inf_prep_sql $DB $update_state]
			inf_exec_stmt $stmt\
					$incr_review\
					$state_id
			inf_close_stmt $stmt
		} msg]} {
			ob::log::write ERROR {unable to execute query : $msg}
			err_bind "Error updating debt state: $msg"
			go_cfg
			return
		}
	}

	msg_bind "Debt state succesfully updated"
	go_cfg
}



#
# ----------------------------------------------------------------------------
# View the Config screen
# ----------------------------------------------------------------------------
#
proc go_cfg args {

	ob::log::write INFO {==> go_cfg}

	global DB
	global DEBT_MAN
	global DEBT_TMPL

	set get_state {
		select
			d1.debt_state_id,
			d1.code,
			d1.description,
			d1.remove_flag,
			d1.add_flag,
			d1.incr_review,
			d1.suspend_account,
			d2.code as next_code
		from
			tDebtState d1,
			outer tDebtState d2
		where
			d1.next_debt_state_id = d2.debt_state_id
	}

	if {[catch {
		set stmt    [inf_prep_sql $DB $get_state]
		set sel_rs  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
	}

	set nrows [db_get_nrows $sel_rs]

	if { $nrows > 0 } {
		for {set i 0} {$i < $nrows} {incr i} {
			set DEBT_MAN($i,debt_state_id)\
				[db_get_col $sel_rs $i debt_state_id]
			set DEBT_MAN($i,code)\
				[db_get_col $sel_rs $i code]
			set DEBT_MAN($i,desc)\
				[db_get_col $sel_rs $i description]
			set DEBT_MAN($i,add_flag)\
				[db_get_col $sel_rs $i add_flag]
			set DEBT_MAN($i,remove_flag)\
				[db_get_col $sel_rs $i remove_flag]
			set DEBT_MAN($i,incr_review)\
				[db_get_col $sel_rs $i incr_review]
			set DEBT_MAN($i,next_code)\
				[db_get_col $sel_rs $i next_code]
			set DEBT_MAN($i,suspend_account)\
				[db_get_col $sel_rs $i suspend_account]
		}
	}
	catch {db_close $sel_rs}

	tpSetVar  debt_num_states $nrows

	tpBindVar debt_state_id       DEBT_MAN  debt_state_id  row_idx
	tpBindVar code                DEBT_MAN  code           row_idx
	tpBindVar desc                DEBT_MAN  desc           row_idx
	tpBindVar add_flag            DEBT_MAN  add_flag       row_idx
	tpBindVar remove_flag         DEBT_MAN  remove_flag    row_idx
	tpBindVar incr_review         DEBT_MAN  incr_review    row_idx
	tpBindVar next_code           DEBT_MAN  next_code      row_idx
	tpBindVar suspend_account     DEBT_MAN  suspend_account row_idx


	asPlayFile -nocache debt_man_config.html
}



#
# -----------------------------------------------------------------------------
# Get list of existing, not-yet-sent letters for this debtState and display them
# -----------------------------------------------------------------------------
#
proc get_letters {debt_state_id} {

	ob::log::write INFO {==> get_letters}

	go_letter_cfg $debt_state_id

	global DB DEBT_LETTER DEBT_TEMPLATE

	set today [clock format [clock seconds] -format {%Y-%m-%d}]
	set sql [subst {
		select
			t.template_name,
			t.template_id,
			l.letter_id,
			l.cr_date
		from
			tDebtTemplate d,
			tLtrTemplate t,
			tLetter l
		where
			d.debt_state_id = ? and
			t.template_id = d.template_id and
			t.template_id = l.template_id and
			l.sent = 'N' and
			l.cr_date >= '$today 00:00:00'
	}]

	if {[catch {
		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt $debt_state_id]
		inf_close_stmt  $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		return
	}

	set nrows [db_get_nrows $rs]
	catch {unset DEBT_LETTER}
	if { $nrows > 0 } {
		for {set i 0} {$i < $nrows} {incr i} {
			# add to letter list, if a non-null letter
			set t_name [db_get_col $rs $i template_name]
			set cr_date [string range\
			 [db_get_col $rs $i cr_date] 0 10]
			set DEBT_LETTER($i,letter_name)\
				"$t_name $cr_date"
			set DEBT_LETTER($i,letter_id)\
				[db_get_col $rs $i letter_id]
			set DEBT_LETTER($i,ltr_tmplt_id)\
				[db_get_col $rs $i template_id]
		}
	}
	catch {db_close $rs}

	tpSetVar  debt_num_letters $nrows

	tpBindVar letter_name       DEBT_LETTER	letter_name       letter_idx
	tpBindVar letter_id         DEBT_LETTER	letter_id         letter_idx
	tpBindVar ltr_tmplt_id      DEBT_LETTER	ltr_tmplt_id      letter_idx

}



#
# ----------------------------------------------------------------------------
# Create a new instance of a letter template
# ----------------------------------------------------------------------------
#
proc create_letter {template_id} {

	global DB

	set sql {
		execute procedure pInsLetter (
			p_template_id = ?
		)
	}

	if {[catch {
		set stmt    [inf_prep_sql $DB $sql]
		set rs      [inf_exec_stmt $stmt $template_id]
		inf_close_stmt  $stmt
	} msg]} {
		catch {db_close $rs}
		ob::log::write ERROR {unable to execute query : $msg}
		return -1
	}

	set letter_id [db_get_coln $rs 0]

	catch {db_close $rs}

	return $letter_id
}



#
# ----------------------------------------------------------------------------
# Display the page to configure letter templates for debt states
# ----------------------------------------------------------------------------
#
proc go_letter_cfg {{arg_debt_state_id -1}} {

	ob::log::write INFO {==> go_letter_cfg}

	if {$arg_debt_state_id == -1} {
		set debt_state_id [reqGetArg debt_state_id]
	} else {
		set debt_state_id $arg_debt_state_id
	}

	global DB DEBT_TEMPLATE DEBT_TMPL

	set get_debt_templates {
		select
			t.template_name,
			t.template_id
		from
			tDebtTemplate d,
			tLtrTemplate t
		where
			d.debt_state_id = ? and
			t.template_id = d.template_id
	}

	if {[catch {
		set stmt [inf_prep_sql $DB $get_debt_templates]
		set rs   [inf_exec_stmt $stmt $debt_state_id]
		inf_close_stmt  $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		return
	}

	set nrows [db_get_nrows $rs]
	catch {unset DEBT_TEMPLATE}
	if { $nrows > 0 } {
		for {set i 0} {$i < $nrows} {incr i} {
			set DEBT_TEMPLATE($i,template_name) [db_get_col $rs $i template_name]
			set DEBT_TEMPLATE($i,template_id)   [db_get_col $rs $i template_id]
		}
	}
	catch {db_close $rs}

	tpSetVar  debt_num_templates $nrows

	tpBindVar template_name  DEBT_TEMPLATE  template_name       template_idx
	tpBindVar template_id    DEBT_TEMPLATE  template_id         template_idx

	if {$arg_debt_state_id != -1} {
		return
	}

	# now, add all letter templates to the mix

	set get_templates {
		select
			template_id,
			template_name
		from
			tLtrTemplate
	}

	if {[catch {
		set stmt    [inf_prep_sql $DB $get_templates]
		set rs      [inf_exec_stmt $stmt]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
	}

	set ntemplates 0
	set tnrows [db_get_nrows $rs]

	if { $tnrows > 0 } {
		for {set i 0} {$i < $tnrows} {incr i} {
			set template_id [db_get_col $rs $i template_id]
			set dup 0
			# remove already selected templates from the list
			for {set k 0} {$k < $nrows} {incr k} {
				if {$DEBT_TEMPLATE($k,template_id) == $template_id} {
					set dup 1
					break
				}
			}
			if {$dup} {
				continue
			}
			set DEBT_TMPL($ntemplates,tmpl_id)   $template_id
			set DEBT_TMPL($ntemplates,tmpl_name) [db_get_col $rs $i template_name]
			incr ntemplates
		}
	}
	catch {db_close $rs}

	tpSetVar  debt_num_tmpl $ntemplates

	tpBindVar tmpl_id       DEBT_TMPL   tmpl_id    tmpl_idx
	tpBindVar tmpl_name     DEBT_TMPL   tmpl_name  tmpl_idx

	tpBindString debt_state_id $debt_state_id

	asPlayFile -nocache debt_letter_cfg.html
}



#
# ----------------------------------------------------------------------------
# Update letter templates for debt states
# ----------------------------------------------------------------------------
#
proc do_letter_cfg {} {

	global DB

	ob::log::write INFO {==> do_letter_cfg}

	set debt_state_id [reqGetArg debt_state_id]

	set act [reqGetArg SubmitName]

	switch -exact -- $act {

		"RemoveDebtTemplate" {

			set template_ids [reqGetArgs select_template]
			if {[llength $template_ids] == 0} {
				err_bind "No template selected"
			} else {
				set rem_template {
					delete from
						tDebtTemplate
					where
						debt_state_id = ? and
						template_id   = ?
				}

				foreach {template_id} $template_ids {
					if {[catch {
						set stmt [inf_prep_sql $DB $rem_template]
						set rs   [inf_exec_stmt $stmt $debt_state_id $template_id]
						inf_close_stmt $stmt
					} msg]} {
						ob::log::write ERROR {unable to execute query : $msg}
						err_bind "Error removing template: $msg"
						break
					} else {
						msg_bind "Template succesfully removed"
					}
				}
			}
		}

		"AddDebtTemplate" {

			set template_id [reqGetArg SelectTmpl]
			if {$template_id == -1 || $template_id == ""} {
				err_bind "No template selected"
			} else {
				set add_template {
					insert into
						tDebtTemplate (debt_state_id, template_id)
					values
						(?,?)
				}

				if {[catch {
					set stmt  [inf_prep_sql $DB $add_template]
					set rs    [inf_exec_stmt $stmt $debt_state_id $template_id]
					inf_close_stmt $stmt
				} msg]} {
					ob::log::write ERROR {unable to execute query : $msg}
					err_bind "Error adding template: $msg"
				} else {
					msg_bind "Template succesfully added"
				}
			}
		}

		"Back" {
			go_cfg
			return
		}

		default {
			err_bind "unexpected debt management operation SubmitName: $act"
		}
	}

	go_letter_cfg
}



#
# ----------------------------------------------------------------------------
# Manually add a new record to the debt diary
# ----------------------------------------------------------------------------
#
proc do_manual_entry {} {
	ob::log::write INFO {==> do_manual_entry}

	set act [reqGetArg acct_no]
	if {$act==""} {
		reqSetArg SubmitName ""
		go_debt_man
		return
	}

	global DB USERID
	
	set acct_no       [reqGetArg acct_no]
	set debt_state_id [reqGetArg DebtState]
	set balance       [reqGetArg balance]
	set notes         [reqGetArg notes]

	if {$acct_no == ""} {
		err_bind "Enter Account number"
		go_manual_entry
	}

	# if balance is empty, use tAcct.balance?
	if {$balance == ""} {
		set balance 0.0
	}

	set sql {
		select
			cust_id
		from
			tCustomer
		where
			acct_no = ?
	}
	if {[catch {
		set stmt  [inf_prep_sql $DB $sql]
		set rs    [inf_exec_stmt $stmt $acct_no]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		err_bind "Error getting customer id: $msg"
		go_manual_entry
	}
	if {[db_get_nrows $rs] != 1} {
		ob::log::write ERROR {No customer found: acct_no $acct_no}
		err_bind "Error getting customer id: no customer found"
		go_manual_entry
	}

	set cust_id [db_get_col $rs 0 cust_id]
	catch {db_close $rs}

	# add to debt diary
	set ret [change_state $cust_id -1 $debt_state_id 1 0 -1]
	if {$ret != 1} {
		err_bind "Error adding debt diary entry"
		go_manual_entry
		return
	}

	set ret [ins_cust_debt_data $cust_id $notes $balance]
	if {$ret != 1} {
		err_bind "Error adding debt diary entry"
		go_manual_entry
		return
	}
	
	msg_bind "Account succesfully added"
	go_manual_entry

}



#
# ----------------------------------------------------------------------------
# Show the screen for manual addition
# ----------------------------------------------------------------------------
#
proc go_manual_entry {} {

	bind_allowed_states
	asPlayFile debt_manual_entry.html
}



#
# ----------------------------------------------------------------------------
# Suspend or unsuspend customer
# ----------------------------------------------------------------------------
#
proc upd_cust_status {cust_id suspend_account} {
	ob::log::write INFO {==> upd_cust_status}
	global DB USERID USERNAME

	# first make sure we need to change the status
	set sql {
		select
			status
		from
			tCustomer
		where
			cust_id = ?
	}
	if {[catch {
		set stmt  [inf_prep_sql $DB $sql]
		set rs    [inf_exec_stmt $stmt $cust_id]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		err_bind "Error updating customer status: $msg"
		return -1
	}
	if {[db_get_nrows $rs] != 1} {
		ob::log::write ERROR {No customer found: cust_id $cust_id}
		err_bind "Error updating customer status: no customer found"
		return -1
	}
	set status [db_get_col $rs 0 status]
	catch {db_close $rs}

	if {$status == "A" && $suspend_account == "N" ||
		$status == "S" && $suspend_account == "Y"} {
		# don't need to change anything
		return 1
	}

	switch -exact -- $suspend_account {

		"Y" {
			# suspend account
			set status "S"
			set reason "Account suspended by Debt Management"
		}

		"N" {
			# activate account
			set status "A"
			set reason "Account activated by Debt Management"
		}

		default {
			# fail
			ob::log::write ERROR {unknown status change}
			err_bind "Unknown status change"
			return -1
		}

	}

	set sql {
		execute procedure pUpdCustStatus
		(
			p_adminuser     = ?,
			p_cust_id       = ?,
			p_status        = ?,
			p_status_reason = ?
		);
	}

	if {[catch {
		set stmt  [inf_prep_sql $DB $sql]
		set rs    [inf_exec_stmt $stmt\
								 $USERNAME\
								 $cust_id\
								 $status\
								 $reason]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		err_bind "Error updating customer status: $msg"
		return -1
	} else {
		msg_bind "Customer status updated succesfully"
	}

	return 1

}



#
# ----------------------------------------------------------------------------
# Display the 13-week customer summary
# ----------------------------------------------------------------------------
#

proc get_cust_stats {cust_id} {

	ob::log::write INFO {==> get_cust_stats}

	global DB
	global WEEKINFO
	global WEEKS

	set num_weeks    13

	set OPTYPE(BWIN) 0
	set OPTYPE(BRFD) 1
	set OPTYPE(BSTK) 2
	set OPTYPE(DEP)  3
	set OPTYPE(SBAL) 4
	set num_vals     5

	# search for the nearest start of a week
	set today [clock seconds]
	set it $today
	for {set d 0} {$d < 7} {incr d} {
		if {[clock format $it -format {%w}] == 0} {
			#sunday
			set end_date $it
			set end_date_ifx [clock format $it -format {%Y-%m-%d}]
			break
		}
		set it [clock scan "-1 day" -base $it]
	}
	
	# now set all the starts of the weeks
	set init_amount [format "%.2f" 0.00]
	set it $end_date
	for {set i 0} {$i < $num_weeks} {incr i} {
		set week_no $i
		set week_start_ifx [clock format\
		 [clock scan "-$week_no weeks" -base $end_date] -format "%Y-%m-%d"]
		set WEEKINFO($i,start) $week_start_ifx
		set WEEKS($week_start_ifx) $i
		for {set j 0} {$j < $num_vals} {incr j} {
			set WEEKINFO($i,$j,amount)  $init_amount
		}
	}
	set start_date_ifx $WEEKINFO(12,start)

	# do the query
	set sql {
		select
			EXTEND(s.start_of_week, YEAR to DAY) as start_of_week,
			amount,
			j_op_type
		from
			tAcct        a,
			tJrnlSummary s
		where
			a.cust_id = ? and
			a.acct_id = s.acct_id and
			s.j_op_type in ('BSTK','DEP','BWIN','BRFD')
			and s.period in ('D','K')
			and s.start_of_week between ? and ?
			and s.system_id = 0
	}

	if {[catch {
		set stmt  [inf_prep_sql $DB $sql]
		set rs    [inf_exec_stmt $stmt\
		                         $cust_id\
		                         $start_date_ifx\
		                         $end_date_ifx]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		err_bind "Error getting customer stats: $msg"
		return
	}

	# then fill in the known values
	set nrows [db_get_nrows $rs]
	if {$nrows > 0} {
		for {set i 0} {$i < $nrows} {incr i} {
			set start_of_week [db_get_col $rs $i start_of_week]
			set amount        [db_get_col $rs $i amount]
			set op_type       [db_get_col $rs $i j_op_type]

			set week_idx $WEEKS($start_of_week)
			set WEEKINFO($week_idx,$OPTYPE($op_type),amount)\
				[format "%.2f" $amount]
		}
	}
	catch {db_close $rs}

	# one more thing, get statement balances from statements generated
	# in this time and put them in the right weeks
	set sql {
		select
			NVL(s.pmt_amount,0)            as pmt_amount,
			EXTEND(s.cr_date, YEAR to DAY) as cr_date,
			WEEKDAY(s.cr_date) as weekday
		from
			tAcct       a,
			tStmtRecord s
		where
			a.cust_id = ?         and
			a.acct_id = s.acct_id and
			s.cr_date between ? and ?
	}

	if {[catch {
		set stmt  [inf_prep_sql $DB $sql]
		set rs    [inf_exec_stmt $stmt\
		                         $cust_id\
		                         "$start_date_ifx 00:00:00"\
		                         "$end_date_ifx 23:59:59"]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		err_bind "Error getting customer stats: $msg"
		return
	}


	# then fill in the known values
	set nrows [db_get_nrows $rs]
	if {$nrows > 0} {
		for {set i 0} {$i < $nrows} {incr i} {
			set cr_date       [db_get_col $rs $i cr_date]
			set amount        [format "%.2f" [db_get_col $rs $i pmt_amount]]
			set weekday       [db_get_col $rs $i weekday]

			set start_of_week [clock format [clock scan "-$weekday days"\
			 -base [clock scan $cr_date]] -format "%Y-%m-%d"]

			set week_idx $WEEKS($start_of_week)
			set WEEKINFO($week_idx,4,amount)\
				[expr {$WEEKINFO($week_idx,4,amount) + $amount}]
		}
	}
	catch {db_close $rs}

	# after that, update all 0.00 balances to ""
	for {set i 0} {$i < $num_weeks} {incr i} {
		if {$WEEKINFO($i,4,amount) == "0.00"} {
			set WEEKINFO($i,4,amount)  ""
		}
	}

	# bind & display
	tpSetVar num_weeks $num_weeks
	tpSetVar num_vals  $num_vals

	tpBindVar amount  WEEKINFO  amount   week_idx     val_idx
	tpBindVar start   WEEKINFO  start    week_idx
}



#
# ----------------------------------------------------------------------------
# Update review dates for selected accounts
# ----------------------------------------------------------------------------
#
proc change_review_dates {debt_state} {
	ob::log::write INFO {==> change_review_dates}

	global DB USERID

	if {[OT_CfgGet RIGHTNOW_DEBT_MAN_ENABLED 1] && [get_state_code $debt_state] != "DS1"} {
		err_bind "Could not update review dates: Customers are not in DS1"
		return
	}

	set cust_id_list [reqGetArgs sc]
	set review_date  [reqGetArg NewReviewDate]

	if { [llength $cust_id_list] == 0} {
		err_bind "No customer selected"
		return
	}

	if {$review_date == ""} {
		err_bind "Enter new review date"
		return
	}

	set debt_diary_ids [list]

	foreach cust_id $cust_id_list {
		lappend debt_diary_ids [reqGetArg DIARY_$cust_id]
	}

	foreach {debt_diary_id} $debt_diary_ids {
		set update_date {
			execute procedure pUpdDebtDiary (
				p_debt_diary_id = ?,
				p_oper_id       = ?,
				p_review_date   = ?
			)
		}

		set c [catch {
			set stmt [inf_prep_sql $DB $update_date]
			inf_exec_stmt   $stmt\
							$debt_diary_id\
							$USERID\
							$review_date
			inf_close_stmt  $stmt
		} msg]

		if {$c} {
			err_bind "Could not update review date: $msg"
			return
		}
	}
	
	msg_bind "Customer debt diary updated"
}


#
# check customer does not have any active entries in debt diary 
# possibly except for debt_diary_id
#
proc check_cust_unique {cust_id {debt_diary_id -1}} {

	global DB

	set sql {
		select
			count(*) as diary_cnt
		from
			tDebtDiary
		where
			cust_id = ?
			and status = 'A'
			and debt_diary_id != ?
	}

	if {[catch {
		set stmt  [inf_prep_sql $DB $sql]
		set rs    [inf_exec_stmt $stmt\
		                         $cust_id\
		                         $debt_diary_id]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		err_bind "Error getting customer stats: $msg"
		return
	}

	set nrows [db_get_nrows $rs]
	set ret   0
	if {$nrows > 0} {
		set cnt [db_get_col $rs 0 diary_cnt]
		if {$cnt > 0} {
			set ret 0
		} else {
			set ret 1
		}
	}
	catch {db_close $rs}
	
	return $ret
}

}
