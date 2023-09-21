# ==============================================================
# $Id: pmt_wtd_risk.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================


namespace eval ADMIN::PMT {

	# Actions.
	asSetAct ADMIN::PMT::DoFraudNotfiy      [namespace code do_fraud_notfiy]
	asSetAct ADMIN::PMT::DoWtdLimits        [namespace code do_wtd_limits]
	asSetAct ADMIN::PMT::DoReturnLimits     [namespace code do_return_limits]
	asSetAct ADMIN::PMT::GoFraudLimits      [namespace code go_fraud_limits]

	# Delete actions handled separatly.
	asSetAct ADMIN::PMT::DoDelFraudNotify   [namespace code do_notify_del]
	asSetAct ADMIN::PMT::DoDelWtdLimits     [namespace code do_wtd_lmt_del]
	asSetAct ADMIN::PMT::DoDelReturnLimits  [namespace code do_return_lmt_del]


	# Display fraud limits page.
	proc go_fraud_limits {{rebind 0}} {
		global DB WTD_LMT

		# Rebind any previous details if replay.
		if {$rebind} {
			rebind_request_data
		}

		# Bind all the parts of the page.
		bind_fraud_notfiy
		bind_wtd_lmts
		bind_return_lmts

		# Play html!
		asPlayFile pmt_fraud/fraud_limits.html

	}


	#------------------------------------------------------------------------------
	# Generic code.
	#------------------------------------------------------------------------------

	# Rebind data sent in the request.
	#	For playback of original page.
	proc rebind_request_data {} {
		for {set i 0} {$i < [reqGetNumVals]} {incr i} {
			tpBindString [reqGetNthName $i] [reqGetNthVal $i]
		}
	}

	# Get form data for the request put in array FORM_DATA
	#	Specific for forms where you update multiple rows in an instance.
	#	request name(s) must be in the form varname_[number], for example:
	#		payMthd_0, payMthd_1, payMthd_2...
	proc get_multi_form_data {} {
		variable FORM_DATA

		if {[info exists FORM_DATA]} {
			unset FORM_DATA
		}

		set num_vals [reqGetNumVals]
		set array_max 0
		for {set i 0} {$i < $num_vals} {incr i} {
			# Split by separator (payMthd_1).
			set pos  [string last "_" [reqGetNthName $i]]

			# If not 'multi form' don't process.
			if {$pos > -1} {
				set name [string range [reqGetNthName $i] 0 [expr {$pos-1}]]
				set num  [string range [reqGetNthName $i] [expr {$pos+1}] end]
				set FORM_DATA($num,$name) [reqGetNthVal $i]

				# Boost the number to the max in the request.
				if {$array_max < $num} {
					set array_max $num
				}
			}
		}

		# Set the array length.
		set FORM_DATA(__length__) [expr {$array_max + 1}]

		return
	}

	# Put all the request data in FORM_DATA.
	# The array is used for validation of the form data.
	proc get_form_data {} {
		variable FORM_DATA

		if {[info exists FORM_DATA]} {
			unset FORM_DATA
		}

		# Set length to '1' because only getting one set of details.
		set FORM_DATA(__length__) 1

		# Get request data.
		set num_vals [reqGetNumVals]
		for {set i 0} {$i < $num_vals} {incr i} {
				set FORM_DATA([reqGetNthName $i]) [reqGetNthVal $i]
		}
	}

	# Does a check for mandatory feilds.
	# Reutrns 1 (OK), 0 (Missing Feilds)
	proc validate_frm_data {madatory_lst {multi 0}} {
		variable FORM_DATA

		for {set i 0} {$i < $FORM_DATA(__length__)} {incr i} {
			foreach item $madatory_lst {
				set name    [lindex $item 0]

				if {[llength $item] > 1} {
					set default_val [lindex $item 1]
				}

				# For form with multiple item of the same name.
				if {$multi} {
					set name "$i,$name"
				}

				if {![info exists FORM_DATA($name)] || $FORM_DATA($name) == ""} {
					if {[info exists default_val]} {
						set FORM_DATA($name) $default_val
					} else {
						return 0
					}
				}
			}
		}

		return 1
	}

	#------------------------------------------------------------------------------
	# Fraud notification.
	#------------------------------------------------------------------------------

	# Configures functionality:
	#	- Notifies an Admin user if an individual wtd is over the "max_wtd"
	proc do_fraud_notfiy args {
		set action [reqGetArg SubmitName]

		switch -- $action {
			goAdd  { go_notify_add }
			doAdd  { do_notify_add }
			doUpd  { do_notify_upd }
			doDel  { do_notify_del }
			goBack { go_fraud_limits }
		}
	}

	proc bind_fraud_notfiy {} {
		global DB NOTIFY_DETAILS

		# Get all rows, for diplay.
		set sql {
			select
				pm.pay_mthd,
				pm.desc as pay_mthd_desc,
				cs.scheme,
				cs.scheme_name as scheme_name,
				ln.max_wtd,
				ln.email
			from
				tfraudlimitnotify ln,
				tPayMthd pm,
				outer tCardSchemeInfo cs
			where
					ln.pay_mthd = pm.pay_mthd
				and ln.scheme   = cs.scheme
		}
		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $rs]
		tpSetVar NumFraudNotify $nrows

		for {set i 0} {$i < $nrows} {incr i} {
			set NOTIFY_DETAILS($i,pay_mthd)  [db_get_col $rs $i pay_mthd]
			set NOTIFY_DETAILS($i,pay_mthd_desc)  [db_get_col $rs $i pay_mthd_desc]
			set NOTIFY_DETAILS($i,scheme)    [db_get_col $rs $i scheme]
			set NOTIFY_DETAILS($i,scheme_name)    [db_get_col $rs $i scheme_name]
			set NOTIFY_DETAILS($i,max_wtd)   [db_get_col $rs $i max_wtd]
			set NOTIFY_DETAILS($i,email)     [db_get_col $rs $i email]
		}
		db_close $rs

		tpBindVar mw_payMthd     NOTIFY_DETAILS pay_mthd      idx
		tpBindVar mw_payMthdDesc NOTIFY_DETAILS pay_mthd_desc idx
		tpBindVar mw_scheme      NOTIFY_DETAILS scheme        idx
		tpBindVar mw_schemeName  NOTIFY_DETAILS schemeName    idx
		tpBindVar mw_maxWtd      NOTIFY_DETAILS max_wtd       idx
		tpBindVar mw_email       NOTIFY_DETAILS email         idx

		# Can the user add any more to this table.
		set sql {
			select
				count(*)
			from
				tPayMthd
			where
				pay_mthd not in (select pay_mthd from tfraudlimitnotify)
				or (pay_mthd == "CC"
					and exists (
								select
									scheme
								from
									tCardSchemeInfo
								where scheme not in (select scheme from tfraudlimitnotify)
								)
					)
		}
		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		if {[db_get_coln $rs 0 0] < 1} {
			tpSetVar disable_add 1
		} else {
			tpSetVar disable_add 0
		}

	}

	# Show 'Add Fraud Notification' screen.
	proc go_notify_add {{rebind 0}} {
		# Bind page options.
		bind_pay_mthds    "wtd_max"
		bind_card_schemes "wtd_max"

		# Rebind any previous details.
		if {$rebind} {
			rebind_request_data
		}

		asPlayFile pmt_fraud/notify_add.html
		return
	}

	# Add fraud notification details.
	proc do_notify_add {} {
		global DB
		variable FORM_DATA

		# Get the request data.
		get_form_data

		# Validate form data.
		if {![validate_frm_data {payMthd maxWtd {scheme ""} email}]} {
			err_bind "Missing required feilds."
			go_notify_add 1
			return
		}

		set sql [subst {
			execute procedure pInsUpdFraudNotify (
				p_pay_mthd = "$FORM_DATA(payMthd)",
				p_scheme   = "$FORM_DATA(scheme)",
				p_max_wtd  = "$FORM_DATA(maxWtd)",
				p_email    = "$FORM_DATA(email)"
			)
		}]
		set stmt [inf_prep_sql $DB $sql]

		if {[catch { set rs  [inf_exec_stmt $stmt] } msg]} {
			ob::log::write ERROR "pInsUpdFraudNotify failed, msg: $msg"
			err_bind "Unable to add entry, msg: $msg"
			go_notify_add 1
			return
		}

		inf_close_stmt $stmt
		db_close $rs

		# Insert successful.
		msg_bind "Added Fraud Notification limit."
		go_fraud_limits
	}

	# Update fraud notification details.
	proc do_notify_upd {} {
		global DB
		variable FORM_DATA

		# Get the request data.
		get_multi_form_data

		# Validate.
		if {![validate_frm_data {mw_payMthd mw_maxWtd mw_email} 1]} {
			err_bind "Missing required feilds."
			go_fraud_limits 1
			return
		}

		# Update items.
		for {set i 0} {$i < $FORM_DATA(__length__)} {incr i} {
			# Update items.
			set sql [subst {
				execute procedure pInsUpdFraudNotify (
					p_pay_mthd = "$FORM_DATA($i,mw_payMthd)",
					p_scheme   = "$FORM_DATA($i,mw_scheme)",
					p_max_wtd  = "$FORM_DATA($i,mw_maxWtd)",
					p_email    = "$FORM_DATA($i,mw_email)"
				)
			}]
			set stmt [inf_prep_sql $DB $sql]

			if {[catch { set rs  [inf_exec_stmt $stmt] } msg]} {
				ob::log::write ERROR "pInsUpdFraudNotify failed, msg: $msg"
				err_bind "Unable to update, msg: $msg"
				go_fraud_limits 1
				return
			}

			inf_close_stmt $stmt
			db_close $rs
		}

		# Success.
		msg_bind "Updated Fraud Notification limits."
		go_fraud_limits
	}

	# Delete a fraud notification limit.
	proc do_notify_del {} {
		global DB USERNAME

		set pay_mthd  [reqGetArg payMthd]
		set scheme    [reqGetArg scheme]

		set sql {
			execute procedure pDelFraudNotify (
				p_adminuser = ?,
				p_pay_mthd  = ?,
				p_scheme    = ?
			)
		}
		set stmt [inf_prep_sql $DB $sql]

		if {[catch {
			set res  [inf_exec_stmt $stmt $USERNAME $pay_mthd $scheme]
		} msg]} {
			ob::log::write ERROR "pDelFraudNotify failed, msg: $msg"
			err_bind "Unable to delete, msg: $msg"
			go_fraud_limits 1
			return
		}
		inf_close_stmt $stmt

		# Go home.
		msg_bind "Deleted Fraud Notification Limit."
		go_fraud_limits
	}



	#------------------------------------------------------------------------------
	# Withdrawal limit notification.
	#------------------------------------------------------------------------------

	# Configures functionality:
	#	- If withdrawal is greater than the limiting factors, an alert is raised.
	proc do_wtd_limits args {
		set action [reqGetArg SubmitName]

		switch -- $action {
			doAdd { do_wtd_lmt_add }
			doDel { do_wtd_lmt_del }
		}
	}

	proc bind_wtd_lmts {} {
		global DB
		global WTD_LMT

		set sql {
			select
				f.limit_id,
				pm.pay_mthd,
				pm.desc as pay_desc,
				f.scheme,
				cs.scheme_name,
				f.days_since_dep_1,
				f.days_since_wtd,
				f.max_wtd
			from
				tFraudLimitWtd f,
				tPayMthd pm,
				outer tCardSchemeInfo cs
			where
					f.pay_mthd  = pm.pay_mthd
				and f.scheme    = cs.scheme
			order by
				f.pay_mthd, f.days_since_dep_1, f.days_since_wtd
		}
		set stmt [inf_prep_sql $DB $sql]
		set rs  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $rs]
		tpSetVar NumFraudLimits $nrows

		set prev_pay_mthd {}
		set prev_pay_schm {}
		for {set i 0} {$i < $nrows} {incr i} {
			set WTD_LMT($i,limit_id)         [db_get_col $rs $i limit_id]
			set WTD_LMT($i,pay_mthd)         [db_get_col $rs $i pay_mthd]
			set WTD_LMT($i,pay_desc)         [db_get_col $rs $i pay_desc]
			set WTD_LMT($i,scheme)           [db_get_col $rs $i scheme]
			set WTD_LMT($i,scheme_name)      [db_get_col $rs $i scheme_name]
			set WTD_LMT($i,first_dep)        [db_get_col $rs $i days_since_dep_1]
			set WTD_LMT($i,days_last_wtd)    [db_get_col $rs $i days_since_wtd]
			set WTD_LMT($i,max_wtd)          [db_get_col $rs $i max_wtd]

			# Set header and footer markers, for the different pay methods.
			if {$prev_pay_mthd != $WTD_LMT($i,pay_mthd) } {
				set WTD_LMT($i,header) 1
				if {$i != 0} {
					set WTD_LMT([expr {$i-1}],footer) 1
				}
			} elseif {$prev_pay_schm != $WTD_LMT($i,scheme)} {
				set WTD_LMT($i,header) 1
				if {$i != 0} {
					set WTD_LMT([expr {$i-1}],footer) 1
				}
			} else {
				set WTD_LMT($i,header) 0
				set WTD_LMT($i,footer) 0
			}


			set prev_pay_mthd $WTD_LMT($i,pay_mthd)
			set prev_pay_schm $WTD_LMT($i,scheme)
		}
		# Last one is always a footer.
		set WTD_LMT([expr {$i-1}],footer) 1

		db_close $rs

		# Bind variables.
		tpBindVar limitId        WTD_LMT limit_id      idx
		tpBindVar payMthd        WTD_LMT pay_mthd      idx
		tpBindVar payDesc        WTD_LMT pay_desc      idx
		tpBindVar scheme         WTD_LMT scheme        idx
		tpBindVar scheme_name    WTD_LMT scheme_name   idx
		tpBindVar firstDep       WTD_LMT first_dep     idx
		tpBindVar daysLastWtd    WTD_LMT days_last_wtd idx
		tpBindVar maxWtd         WTD_LMT max_wtd       idx

		# Bind form data.
		bind_card_schemes "wtd_limits"
		bind_pay_mthds    "wtd_limits"

		return
	}

	proc do_wtd_lmt_add {} {
		global DB
		variable FORM_DATA

		# Get the request data.
		get_form_data

		# Validate form data.
		set form_ok [validate_frm_data {payMthd \
						new_firstDep \
						new_daysLastWtd \
						new_maxWtd \
		}]

		if {!$form_ok} {
			err_bind "Missing required feilds."
			go_fraud_limits 1
			return
		}

		set sql {
			execute procedure pInsFraudWtdLimits (
				p_pay_mthd         = ?,
				p_scheme           = ?,
				p_days_since_dep_1 = ?,
				p_days_since_wtd   = ?,
				p_max_wtd          = ?
			)
		}
		set stmt [inf_prep_sql $DB $sql]
		if {[catch { set rs  [inf_exec_stmt $stmt $FORM_DATA(payMthd) \
												$FORM_DATA(payScheme) \
												$FORM_DATA(new_firstDep) \
												$FORM_DATA(new_daysLastWtd) \
												$FORM_DATA(new_maxWtd) \
		] } msg]} {
			ob::log::write ERROR "pInsFraudWtdLimits failed, msg: $msg"
			err_bind "Unable to insert, msg: $msg"
			go_fraud_limits 1
			return
		}
		inf_close_stmt $stmt
		db_close $rs

		msg_bind "Inserted Limit."
		go_fraud_limits

	}

	proc do_wtd_lmt_del {} {
		global DB USERNAME

		set limit_id [reqGetArg limitId]

		set sql {
			execute procedure pDelFraudWtdLimits (
				p_adminuser        = ?,
				p_limit_id         = ?
			)
		}

		set stmt [inf_prep_sql $DB $sql]
		if {[catch { set res  [inf_exec_stmt $stmt $USERNAME $limit_id] } msg]} {
			ob::log::write ERROR "pDelFraudWtdLimits failed, msg: $msg"
			err_bind "Unable to delete, msg: $msg"
			go_fraud_limits 1
			return
		}
		inf_close_stmt $stmt
		db_close $res

		msg_bind "Deleted limit."
		go_fraud_limits
	}


	#------------------------------------------------------------------------------
	# Return limit notification.
	#------------------------------------------------------------------------------

	# Configures functionality:
	#	- If return is greater than limiting factors, a flag is put on the users account.
	proc do_return_limits args {
		set action [reqGetArg SubmitName]

		switch -- $action {
			goAdd { go_return_lmt_add }
			doAdd { do_return_lmt_add }
			doUpd { do_return_lmt_upd }
			doDel { do_return_lmt_del }
		}
	}

	proc bind_return_lmts {} {
		global DB
		global LARGE_RETURNS

		# To prevent have a stupidly large query, its makes the
		#   union on the fly.
		#	productArea    tableName     foreignKey
		set table_map { \
			{ESB           tEvCategory   ev_category_id} \
			{XSYS          tXSysHost     system_id}   \
			{POOL          -             -}   \
			{FOG           -             -}   \
			{LOTO          -             -}   \
		}

		set sql_parts {}
		foreach item $table_map {
			set key   [lindex $item 0]
			set table [lindex $item 1]
			set f_key [lindex $item 2]

			if {$table != "-"} {
				lappend sql_parts [subst {
					select
						fr.product_area,
						NVL(fr.ref_id, -1) ref_id,
						fr.limit,
						NVL(rt.name,"--DEFAULT--") as ref_name
					from
						tFraudLmtReturns fr,
						outer $table rt
					where
							fr.product_area == "$key"
						and fr.ref_id = rt.$f_key
				}]
			} else {
				lappend sql_parts [subst {
					select
						fr.product_area,
						NVL(fr.ref_id, -1) ref_id,
						fr.limit,
						"n/a" as ref_name
					from
						tFraudLmtReturns fr
					where
						fr.product_area == "$key"
				}]
			}
		}
		# Union these queries.
		set sql [join $sql_parts "UNION ALL"]
		append sql " order by 2"

		ob::log::write INFO "$sql"

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		# Get/Bind the data.
		set nrows [db_get_nrows $res]
		tpSetVar LargeLmtNum $nrows
		for {set i 0} {$i < $nrows} {incr i} {
			set LARGE_RETURNS($i,product_area)   [db_get_col $res $i product_area]
			set LARGE_RETURNS($i,ref_id)         [db_get_col $res $i ref_id]
			set LARGE_RETURNS($i,ref_name)       [ADMIN::EV_SEL::remove_tran_bars [db_get_col $res $i ref_name]]
			set LARGE_RETURNS($i,limit)          [db_get_col $res $i limit]
		}

		tpBindVar productArea LARGE_RETURNS product_area   idx
		tpBindVar refId       LARGE_RETURNS ref_id    idx
		tpBindVar refName     LARGE_RETURNS ref_name  idx
		tpBindVar limit       LARGE_RETURNS limit     idx

	}

	proc go_return_lmt_add {{rebind 0}} {
		global DB

		if {$rebind} {
			rebind_request_data
		}

		# Bind combos.
		bind_sports_cats
		bind_ex_hosts

		asPlayFile pmt_fraud/returns_add.html
	}

	proc do_return_lmt_add {} {
		global DB
		variable FORM_DATA

		# Get the request data.
		get_form_data

		if {$FORM_DATA(subType) == -1} {
			set formattedSubType null
		} else {
			set formattedSubType "\"$FORM_DATA(subType)\""
		}

		set sql [subst {
			execute procedure pSetFraudLmtReturns (
				p_product_area      = "$FORM_DATA(type)",
				p_ref_id       = $formattedSubType,
				p_limit        = "$FORM_DATA(amt)"
			)
		}]
		set stmt [inf_prep_sql $DB $sql]

		if {[catch { set rs  [inf_exec_stmt $stmt] } msg]} {
			ob::log::write ERROR "pInsFraudLmtReturns failed, msg: $msg"
			err_bind "Unable to insert, msg: $msg"
			go_return_lmt_add 1
			return
		}
		inf_close_stmt $stmt
		db_close $rs

		# Success!
		msg_bind "Updated Fraud Notification details."
		go_fraud_limits
	}

	proc do_return_lmt_upd {} {
		global DB
		variable FORM_DATA

		# Get request data.
		get_multi_form_data

		# Validate.
		if {![validate_frm_data {productArea refId limit} 1]} {
			err_bind "Missing required feilds."
			go_fraud_limits 1
			return
		}



		# Update items.
		for {set i 0} {$i < $FORM_DATA(__length__)} {incr i} {
			if {$FORM_DATA($i,refId) == -1} {
				set formattedRefId null
			} else {
				set formattedRefId "\"$FORM_DATA($i,refId)\""
			}

			# Update items.
			set sql [subst {
				execute procedure pSetFraudLmtReturns (
					p_product_area = "$FORM_DATA($i,productArea)",
					p_ref_id       = $formattedRefId,
					p_limit        = "$FORM_DATA($i,limit)"
				)
			}]
			set stmt [inf_prep_sql $DB $sql]

			if {[catch { set rs  [inf_exec_stmt $stmt] } msg]} {
				ob::log::write ERROR "pSetFraudLmtReturns failed, msg: $msg"
				err_bind "Unable to update, msg: $msg"
				go_fraud_limits 1
				return
			}

			inf_close_stmt $stmt
			db_close $rs
		}

		# Success.
		msg_bind "Updated Large Return limits."
		go_fraud_limits

	}

	proc do_return_lmt_del {} {
		global DB
		global USERNAME

		set product_area [reqGetArg productArea]
		set ref_id  [reqGetArg refId]

		if {$ref_id == -1} {
			set formattedSubType null
		} else {
			set formattedSubType "\"$ref_id\""
		}

		set sql [subst {
			execute procedure pDelFraudLmtReturns (
				p_adminuser = ?,
				p_product_area   = ?,
				p_ref_id    = $formattedSubType
			)
		}]
		set stmt [inf_prep_sql $DB $sql]

		if {[catch { set rs  [inf_exec_stmt $stmt $USERNAME $product_area] } msg]} {
			ob::log::write ERROR "pDelFraudLmtReturns failed, msg: $msg"
			err_bind "Unable to delete, msg: $msg"
			go_fraud_limits 1
			return
		}
		inf_close_stmt $stmt
		db_close $rs

		# Success!
		msg_bind "Successfully deleted large returns limit."
		go_fraud_limits
	}



	#------------------------------------------------------------------------------
	#	Combo bindings.
	#		Bindings for combo boxes not specific to functionality
	#------------------------------------------------------------------------------

	proc bind_pay_mthds {exlusion_type} {
		global DB
		global PAY_MTHDS

		set sql {}

		if {$exlusion_type == "wtd_max"} {
			set sql {
				select
					pay_mthd,
					desc
				from
					tPayMthd
				where
					pay_mthd not in (select pay_mthd from tFraudLimitNotify)
					or (pay_mthd == "CC"
						and exists (
									select
										scheme
									from
										tCardSchemeInfo
									where
										scheme not in (select scheme from tFraudLimitNotify where scheme is not null)
									)
						)
			}
		} elseif {$exlusion_type == "wtd_limits"} {
			set sql {
				select
					pay_mthd,
					desc
				from
					tPayMthd
				where
					pay_mthd not in (select pay_mthd from tFraudLimitWtd)
					or (pay_mthd == "CC"
						and exists (
									select
										scheme
									from
										tCardSchemeInfo
									where
										scheme not in (select scheme from tFraudLimitWtd where scheme is not null)
									)
						)
			}
		}

		ob::log::write ERROR "exlusion_type : $exlusion_type"

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $res]
		tpSetVar NumPayMthds $nrows

		for {set i 0} {$i < $nrows} {incr i} {
			set PAY_MTHDS($i,pay_mthd) [db_get_col $res $i pay_mthd]
			set PAY_MTHDS($i,desc)     [db_get_col $res $i desc]
		}

		tpBindVar cmb_pay_mthd PAY_MTHDS pay_mthd pay_mtd_idx
		tpBindVar cmb_desc     PAY_MTHDS desc     pay_mtd_idx

		db_close $res
	}

	proc bind_card_schemes {exlusion_type} {
		global DB
		global CARD_SCHEME

		set sql {}
		if {$exlusion_type == "wtd_max"} {
			set sql {
				select
					si.scheme,
					si.scheme_name
				from
					tCardSchemeInfo si
				where
					si.scheme not in (select tn.scheme from tFraudLimitNotify tn where tn.scheme is not null)
			}
		} elseif {$exlusion_type == "wtd_limits"} {
			set sql {
				select
					si.scheme,
					si.scheme_name
				from
					tCardSchemeInfo si
				where
					si.scheme not in (select lw.scheme from tFraudLimitWtd lw where lw.scheme is not null)
			}
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $res]
		tpSetVar NumSchemes $nrows

		for {set i 0} {$i < $nrows} {incr i} {
			set CARD_SCHEME($i,scheme)      [db_get_col $res $i scheme]
			set CARD_SCHEME($i,scheme_name) [db_get_col $res $i scheme_name]
		}

		tpBindVar cmb_scheme      CARD_SCHEME scheme      scheme_idx
		tpBindVar cmb_scheme_name CARD_SCHEME scheme_name scheme_idx

		db_close $res
	}

	# Binds sports categories for the add large return limit page.
	# If acct_id is -1, this is for the global page, otherwise,
	# it searches for account level entries.
	proc bind_sports_cats {{acct_id -1}} {
		global  DB
		global  SPORTS_CATS

		if {$acct_id >= 0} {
			set existing_cats_subquery [subst {
				select
					NVL(ref_id,-1)
				from
					tFraudLmtRetAcct
				where
					product_area = "ESB" and
					acct_id = $acct_id
			}]
		} else {
			set existing_cats_subquery {
				select
					NVL(ref_id,-1)
				from
					tFraudLmtReturns
				where
					product_area = "ESB"
			}
		}

		set sql [subst {
			select
				ev_category_id,
				name
			from
				tEvCategory
			where
				ev_category_id not in ($existing_cats_subquery)
			order by
				disporder
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt


		set nrows [db_get_nrows $res]
		tpSetVar NumSportsCats $nrows

		for {set i 0} {$i < $nrows} {incr i} {
			set SPORTS_CATS($i,category)  [db_get_col $res $i ev_category_id]
			set SPORTS_CATS($i,name)      [ADMIN::EV_SEL::remove_tran_bars [db_get_col $res $i name]]
		}

		tpBindVar sc_id    SPORTS_CATS category   cat_idx
		tpBindVar sc_name  SPORTS_CATS name       cat_idx

		db_close $res
	}


	# Binds external hosts for the add large return limit page.
	# If acct_id is -1, this is for the global page, otherwise,
	# it searches for account level entries.
	proc bind_ex_hosts {{acct_id -1}} {
		global   DB
		global   EX_HOSTS

		if {$acct_id >= 0} {
			set existing_cats_subquery [subst {
				select
					NVL(ref_id,-1)
				from
					tFraudLmtRetAcct
				where
					product_area = "XSYS" and
					acct_id = $acct_id
			}]
		} else {
			set existing_cats_subquery {
				select
					NVL(ref_id,-1)
				from
					tFraudLmtReturns
				where
					product_area = "XSYS"
			}
		}

		set sql [subst {
			select
				system_id,
				name
			from
				tXSysHost
			where
				system_id not in ($existing_cats_subquery)
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt


		set nrows [db_get_nrows $res]
		tpSetVar NumExtHosts $nrows

		for {set i 0} {$i < $nrows} {incr i} {
			set EX_HOSTS($i,system_id)  [db_get_col $res $i system_id]
			set EX_HOSTS($i,name)       [db_get_col $res $i name]
		}

		tpBindVar eh_id        EX_HOSTS system_id ext_idx
		tpBindVar eh_name      EX_HOSTS name      ext_idx

		db_close $res
	}

# close namespace
}
