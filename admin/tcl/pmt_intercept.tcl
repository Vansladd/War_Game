# ==============================================================
# $Id: pmt_intercept.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

#
# ----------------------------------------------------------------------------
# Procedures called from here do their own transaction management
# ----------------------------------------------------------------------------
#
namespace eval ADMIN::PMTINTCPT {

asSetAct ADMIN::PMTINTCPT::GoPmtIntercept        [namespace code go_pmt_intercept]
asSetAct ADMIN::PMTINTCPT::GoPmtInterceptCCY     [namespace code go_pmt_intercept_ccy]
asSetAct ADMIN::PMTINTCPT::DoPmtInterceptCCY     [namespace code do_pmt_intercept_ccy]
asSetAct ADMIN::PMTINTCPT::GoPmtInterceptDefn    [namespace code go_pmt_intercept_defn]
asSetAct ADMIN::PMTINTCPT::DoPmtInterceptDefn    [namespace code do_pmt_intercept_defn]
asSetAct ADMIN::PMTINTCPT::GoPmtInterceptBank    [namespace code go_pmt_intercept_bank]
asSetAct ADMIN::PMTINTCPT::DoPmtInterceptBank    [namespace code do_pmt_intercept_bank]
asSetAct ADMIN::PMTINTCPT::GoPmtInterceptCountry [namespace code go_pmt_intercept_country]
asSetAct ADMIN::PMTINTCPT::DoPmtInterceptCountry [namespace code do_pmt_intercept_country]

	#
	# Display the payment intercept data
	#
	proc go_pmt_intercept {} {

		global DB CCY

		#
		# Check permission
		#
		if {![op_allowed ViewPmtIntercepts]} {

			#display no permission error
			error "You do not have permission to view payment intercepts"
			return
		}

		#
		# Intercept Currencies
		#
		set ccySql [subst {
			select
				ccy_code          as ccy,
				int_all           as flag,
				status            as status,
				int_refer_email   as refer_email,
				int_decline_email as decline_email,
				int_email_sender  as sender,
				int_refused_email as refuse_email
			from
				tPmtIntcptCCY
			order by ccy_code

		}]

		set ccyStmt [inf_prep_sql $DB $ccySql]
		set ccyRes  [inf_exec_stmt $ccyStmt]
		inf_close_stmt $ccyStmt

		#Store the currency data
		bind_rs  $ccyRes CCY ccy_idx
		db_close $ccyRes

		#Play template
		asPlayFile -nocache "pmt/pmt_intercept_list.html"

		#Cleanup
		catch {unset CCY}
	}


	#
	# Display the payment intercept currency
	#
	proc go_pmt_intercept_ccy {} {

		global DB CCY INTCPT BANK COUNTRY

		#
		# Check permission
		#
		if {![op_allowed ViewPmtIntercepts]} {

			#display no permission error
			error "You do not have permission to view payment intercepts"
			return
		}

		#Check which operation we're after
		set operation [reqGetArg SubmitName]
		array set INTCPT [list]

		if {$operation == "Upd"} {

			# Display update page - pull out existing info
			tpSetVar operation Upd
			set ccy_code [reqGetArg ccy_code]

			set ccySql [subst {
				select
					ccy_code,
					int_all,
					status,
					int_refer_email,
					int_decline_email,
					int_email_sender,
					int_refused_email
				from
					tPmtIntcptCCY
				where
					ccy_code = '$ccy_code'
			}]

			# Execute SQL
			set ccyStmt [inf_prep_sql $DB $ccySql]
			set ccyRes  [inf_exec_stmt $ccyStmt]
			inf_close_stmt $ccyStmt

			if {[db_get_nrows $ccyRes] == 0} {
				err_bind "Could not find ccy record for id $ccy_id"
 		    } else {
				# Bind ccy data
				tpBindString ccy_code  		$ccy_code
				tpBindString int_all 		[db_get_col $ccyRes 0 int_all]
				tpBindString status 		[db_get_col $ccyRes 0 status]
				tpBindString refer_email 	[db_get_col $ccyRes 0 int_refer_email]
				tpBindString decline_email 	[db_get_col $ccyRes 0 int_decline_email]
				tpBindString email_sender 	[db_get_col $ccyRes 0 int_email_sender]
				tpBindString refused_email 	[db_get_col $ccyRes 0 int_refused_email]
			}
			db_close $ccyRes

		} elseif {$operation == "Add"} {

			# Display add new ccy page
			tpSetVar operation Add

		}

		#Play template
		asPlayFile -nocache "pmt/pmt_intercept_ccy.html"

	}

	#
	# Perform action on payment intercept currency
	#
	proc do_pmt_intercept_ccy {} {

		global DB BANK

		#Check we've the appropriate permissions
		if {![op_allowed ManagePmtIntercepts]} {
			err_bind "You do not have permission to amend the currency details"
			go_pmt_intercept
			return
		}

		#Check which operation we're after
		set operation [reqGetArg SubmitName]
		OT_LogWrite 5 " => do_pmt_intercept_ccy. SubmitName = $operation"

		if {$operation == "Del"} {

			# Retrieve the currency code to delete
			set ccy_code [reqGetArg ccy_code]
			if {$ccy_code == ""} {
				err_bind "Invalid currency code"
				go_pmt_intercept
				return
			}

			# Delete associated intercepts
			set defnSQL [ subst {

				delete from tPmtIntcptDefn
				where ccy_code = '$ccy_code'
			}]
			set defnStmt [inf_prep_sql $DB $defnSQL]
			inf_exec_stmt $defnStmt
			inf_close_stmt $defnStmt


			# Delete the currency
			set ccySQL [subst {

				delete from tPmtIntcptCCY
				where ccy_code = '$ccy_code'
			}]
			set ccyStmt [inf_prep_sql $DB $ccySQL]
			inf_exec_stmt $ccyStmt
			inf_close_stmt $ccyStmt

			#Display ccy list
			go_pmt_intercept

		} elseif {$operation == "Upd" || $operation == "Add"} {

			# Retrieve the currency info
			set ccy_code      [reqGetArg ccy_code]
			set status        [reqGetArg status]
			set int_all       [reqGetArg int_all]
			set refer_email   [reqGetArg refer_email]
			set decline_email [reqGetArg decline_email	]
			set refused_email [reqGetArg refused_email]
			set email_sender  [reqGetArg email_sender]

			#Check the fields
			set errors [list]
			if {$ccy_code == "" || [string length $ccy_code] > 3} {
				lappend errors "Invalid currency code"
			}
			if {$refer_email == ""} {
				lappend errors "Invalid referral payment email address"
			}
			if {$decline_email == ""} {
				lappend errors "Invalid declined payment email address"
			}
			if {$refused_email == ""} {
				lappend errors "Invalid customer refused email address"
			}
			if {$email_sender == ""} {
				lappend errors "Invalid sender email address"
			}
			if {[llength $errors] > 0} {
				err_bind [join $errors "<br>"]
				go_pmt_intercept
				return
			}


			if {$operation == "Upd"} {

				#Perform Update
				set ccySQL [subst {

					update
						tPmtIntcptCCY
					set
						status            = '$status',
						int_all           = '$int_all',
						int_refer_email   = '$refer_email',
						int_decline_email = '$decline_email',
						int_refused_email = '$refused_email',
						int_email_sender  = '$email_sender'
					where
						ccy_code = '$ccy_code'
				}]

			} else {

				#Perform Insertion
				set ccySQL [subst {

					insert into tPmtIntcptCCY
					(
						ccy_code,
						status,
						int_all,
						int_refer_email,
						int_decline_email,
						int_refused_email,
						int_email_sender
					)
					values
					(
						'$ccy_code',
						'$status',
						'$int_all',
						'$refer_email',
						'$decline_email',
						'$refused_email',
						'$email_sender'
					)
				}]

			}

			# Execute SQL

			set ccyStmt [inf_prep_sql $DB $ccySQL]
			inf_exec_stmt $ccyStmt
			inf_close_stmt $ccyStmt

			#Display ccy list
			go_pmt_intercept

		} else {

			err_bind "Unknown operation $operation"
			go_pmt_intercept
		}
	}


	#
	# Display the intercept definitions for the passed currency
	#
	proc go_pmt_intercept_defn {} {

		global DB INTCPT BANK COUNTRY

		catch {unset INTCPT}
		catch {unset BANK}
		catch {unset COUNTRY}

		#
		# Check permission
		#
		if {![op_allowed ViewPmtIntercepts]} {

			#display no permission error
			error "You do not have permission to view payment intercepts"
			return
		}

		#Check we have a currency code to work with
		set ccy_code [reqGetArg ccy_code]
		if {$ccy_code == "" || [string length $ccy_code] > 3} {
			err_bind "Invalid currency code : $ccy_code"
			go_pmt_intercept
			return
		}
		tpBindString ccy_code $ccy_code

		# Build bank list, regardless of operation type
		set bankSql [subst {
			select
				int_bank_id as bank_id,
				bank_string as bank_name,
				status
			from
				tPmtIntcptBank
			order by
				bank_string
		}]

		# Execute SQL
		set bankStmt [inf_prep_sql $DB $bankSql]
		set bankRes  [inf_exec_stmt $bankStmt]
		inf_close_stmt $bankStmt

		#Store the bank data
		bind_rs  $bankRes BANK bank_idx
		db_close $bankRes

		# Build country list, regardless of operation type
		set countrySql [subst {
			select
				int_country_id as country_id,
				country_string as country_name,
				status
			from
				tPmtIntcptCntry
			order by
				country_string
		}]

		# Execute SQL
		set countryStmt [inf_prep_sql $DB $countrySql]
		set countryRes  [inf_exec_stmt $countryStmt]
		inf_close_stmt $countryStmt

		#Store the country data
		bind_rs  $countryRes COUNTRY country_idx
		db_close $countryRes

		# Pull out the intercept definitions
		set defnSql [subst {
			select
				int_bank_id as bank_id,
				int_country_id as country_id,
				int_type as type
			from
				tPmtIntcptDefn
			where
				ccy_code = '$ccy_code'
		}]

		# Execute SQL
		set defnStmt 	[inf_prep_sql $DB $defnSql]
		set defnRes  	[inf_exec_stmt $defnStmt]
		inf_close_stmt 	$defnStmt

		# Store in the intercept array
		set nrows [db_get_nrows $defnRes]
		for {set i 0} {$i < $nrows} {incr i} {
			OT_LogWrite 10 "Setting intercept: ccy=$ccy_code, bank_id=[db_get_col $defnRes $i bank_id], country_id=[db_get_col $defnRes $i country_id], type=[db_get_col $defnRes $i type]"
			set INTCPT([db_get_col $defnRes $i bank_id],[db_get_col $defnRes $i country_id]) [db_get_col $defnRes $i type]
		}
		db_close $defnRes

		#Fill all empty slots in the INTCPT array
		for {set i 0} {$i < $BANK(nrows)} {incr i} {
			for {set j 0} {$j < $COUNTRY(nrows)} {incr j} {
				if {![info exists INTCPT($BANK($i,bank_id),$COUNTRY($j,country_id))]} {
					set INTCPT($BANK($i,bank_id),$COUNTRY($j,country_id)) "-"
				}
			}
		}

		#Display the intercepts
		asPlayFile -nocache "pmt/pmt_intercept_defn.html"

		catch {unset INTCPT}
		catch {unset BANK}
		catch {unset COUNTRY}

	}


	#
	# Update the intercept definitions
	#
	proc do_pmt_intercept_defn {} {

		global DB

		#Check we've the appropriate permissions
		if {![op_allowed ManagePmtIntercepts]} {
			err_bind "You do not have permission to amend the bank details"
			reqSetArg SubmitName All
			go_pmt_intercept_bank
		}

		# Extract the currency
		set ccy_code [reqGetArg ccy_code]
		if {$ccy_code == ""} {
			err_bind "No currency supplied"
			go_pmt_intercept
			return
		}

		# Handle our own transactions
		inf_begin_tran $DB

		# Remove the existing intercept definitions
		set delSQL [subst {
			delete from tPmtIntcptDefn
			where ccy_code = '$ccy_code'
		}]

		# Execute SQL
		OT_LogWrite 5 "Deleting all current intercepts for $ccy_code"
		set delStmt 	[inf_prep_sql $DB $delSQL]
		inf_exec_stmt $delStmt
		inf_close_stmt 	$delStmt

		# Prepare the SQL for inserting new intercepts
		set insSQL [subst {

			insert into tPmtIntcptDefn
			(
				ccy_code,
				int_bank_id,
				int_country_id,
				int_type
			)
			values
			(
				'$ccy_code',
				?,
				?,
				?
			)
		}]
		set insStmt 	[inf_prep_sql $DB $insSQL]

		# Retrieve the intercept data and store
		for {set i 0} {$i < [reqGetNumVals]} {incr i} {

			#Retrieve the name of the current argument
			set arg [reqGetNthName $i]
			OT_LogWrite 10 "Examining argument $arg"

			#Check if this is an intercept definition, or just another form variable
			if {[regexp "INTCPT_(\[0-9\]+)_(\[0-9\]+)" $arg all bank_id country_id]} {

				#Get the type and check whether an intercept was requested
				set type [reqGetArg $arg]
				if {[lsearch [list D A R] $type] != -1} {

					#Insert intercept record
					OT_LogWrite 5 "Inserting intercept for ccy=$ccy_code, bank_id=$bank_id, country_id=$country_id, type=$type"
					inf_exec_stmt $insStmt $bank_id $country_id $type
				}
			}
		}
		inf_close_stmt $insStmt

		#If we've reached here then all is OK, so commit the transaction
		inf_commit_tran $DB

		#All good
		go_pmt_intercept
	}


	#
	# Display the payment intercept banks
	#
	proc go_pmt_intercept_bank {} {

		global DB BANK

		#
		# Check permission
		#
		if {![op_allowed ViewPmtIntercepts]} {

			#display no permission error
			error "You do not have permission to view payment intercepts"
			return
		}

		#Check which operation we're after
		set operation [reqGetArg SubmitName]

		if {$operation == "Upd"} {

			# Display update page
			tpSetVar operation Upd
			set bank_id [reqGetArg bank_id]

			set bankSql [subst {
				select
					bank_string as bank_name,
					status
				from
					tPmtIntcptBank
				where
					int_bank_id = $bank_id
			}]

			# Execute SQL
			set bankStmt [inf_prep_sql $DB $bankSql]
			set bankRes  [inf_exec_stmt $bankStmt]
			inf_close_stmt $bankStmt

			if {[db_get_nrows $bankRes] == 0} {
				err_bind "Could not find bank record for id $bank_id"
 		    } else {
				# Bind bank data
				tpBindString bank_id   $bank_id
				tpBindString bank_name [db_get_col $bankRes 0 bank_name]
				tpBindString status    [db_get_col $bankRes 0 status]
			}

			#Play template
			asPlayFile -nocache "pmt/pmt_intercept_banks.html"

		} elseif {$operation == "Add"} {

			# Display add new bank page
			tpSetVar operation Add

			#Play template
			asPlayFile -nocache "pmt/pmt_intercept_banks.html"

		} else {


			if {$operation == "All"} {

				# Display all banks
				tpSetVar operation all

				set bankSql [subst {
					select
						int_bank_id as bank_id,
						bank_string as bank_name,
						status
					from
						tPmtIntcptBank
					order by
						bank_string
				}]

			} else {

				# Search banks
				tpSetVar operation srch
				set bank_name [string toupper [reqGetArg bank_name]]

				set bankSql [subst {
					select
						int_bank_id as bank_id,
						bank_string as bank_name,
						status
					from
						tPmtIntcptBank
					where
						bank_string like '${bank_name}%'
					order by
						bank_string
				}]
			}

			# Execute SQL
			set bankStmt [inf_prep_sql $DB $bankSql]
			set bankRes  [inf_exec_stmt $bankStmt]
			inf_close_stmt $bankStmt

			#Store the bank data
			bind_rs  $bankRes BANK bank_idx
			db_close $bankRes

			#Play template
			asPlayFile -nocache "pmt/pmt_intercept_banks.html"

			#Cleanup
			catch {unset BANK}
		}
	}


	#
	# Perform action on payment intercept bank
	#
	proc do_pmt_intercept_bank {} {

		global DB BANK

		#Check we've the appropriate permissions
		if {![op_allowed ManagePmtIntercepts]} {
			err_bind "You do not have permission to amend the bank details"
			reqSetArg SubmitName All
			go_pmt_intercept_bank
		}

		#Check which operation we're after
		set operation [reqGetArg SubmitName]
		OT_LogWrite 5 " => do_pmt_intercept_bank. SubmitName = $operation"

		if {$operation == "Upd"} {

			#Update an existing record
			set name   [string toupper [reqGetArg bank_name]]
			set status [reqGetArg status]
			set id     [reqGetArg bank_id]

			#Check we have a vaild bank name
			if {$name == ""} {
				err_bind "Bank name cannot be empty"
				go_pmt_intercept_bank
				return
			}

			#Update the record
			set bankSql [subst {
				update
					tPmtIntcptBank
				set
					bank_string = '$name',
					status      = '$status'
				where
					int_bank_id = $id}]

			# Execute SQL


			set bankStmt [inf_prep_sql $DB $bankSql]
			inf_exec_stmt $bankStmt
			inf_close_stmt $bankStmt

			#Display bank list
			reqSetArg SubmitName All
			go_pmt_intercept_bank

		} elseif {$operation == "Add"} {

			#Add new existing record
			set name   [string toupper [reqGetArg bank_name]]
			set status [reqGetArg status]

			#Check we have a vaild bank name
			if {$name == ""} {
				err_bind "Bank name cannot be empty"
				go_pmt_intercept_bank
				return
			}

			#Insert the record
			set bankSql [subst {

				Insert into tPmtIntcptBank
				(
					bank_string,
					status
				)
				values
				(
					'$name',
					'$status'
				)
			}]

			# Execute SQL
			set bankStmt [inf_prep_sql $DB $bankSql]
			inf_exec_stmt $bankStmt
			inf_close_stmt $bankStmt

			#Display bank list
			reqSetArg SubmitName All
			go_pmt_intercept_bank

		} elseif {$operation == "Del"} {

			# Delete record
			set id   [reqGetArg bank_id]

			# Delete associated intercepts
			set defnSQL [ subst {
				delete from tPmtIntcptDefn
				where int_bank_id = $id
			}]
			set defnStmt [inf_prep_sql $DB $defnSQL]
			inf_exec_stmt $defnStmt
			inf_close_stmt $defnStmt

			# Delete the record
			set bankSql [subst {

				Delete from tPmtIntcptBank
				where int_bank_id = $id
			}]

			# Execute SQL
			set bankStmt [inf_prep_sql $DB $bankSql]
			inf_exec_stmt $bankStmt
			inf_close_stmt $bankStmt

			#Display bank list
			reqSetArg SubmitName All
			go_pmt_intercept_bank

		} else {

			err_bind "Unknown operation $operation"
			go_pmt_intercept_bank
		}
	}



	#
	# Display the payment intercept countries
	#
	proc go_pmt_intercept_country {} {

		global DB COUNTRY

		#
		# Check permission
		#
		if {![op_allowed ViewPmtIntercepts]} {

			#display no permission error
			error "You do not have permission to view payment intercepts"
			return
		}

		#Check which operation we're after
		set operation [reqGetArg SubmitName]

		if {$operation == "Upd"} {

			# Display update page
			tpSetVar operation Upd
			set country_id [reqGetArg country_id]

			set countrySql [subst {
				select
					country_string as country_name,
					status
				from
					tPmtIntcptCntry
				where
					int_country_id = $country_id
			}]

			# Execute SQL
			set countryStmt [inf_prep_sql $DB $countrySql]
			set countryRes  [inf_exec_stmt $countryStmt]
			inf_close_stmt $countryStmt

			if {[db_get_nrows $countryRes] == 0} {
				err_bind "Could not find country record for id $country_id"
 		    } else {
				# Bind country data
				tpBindString country_id   $country_id
				tpBindString country_name [db_get_col $countryRes 0 country_name]
				tpBindString status    [db_get_col $countryRes 0 status]
			}

			#Play template
			asPlayFile -nocache "pmt/pmt_intercept_countries.html"

		} elseif {$operation == "Add"} {

			# Display add new country page
			tpSetVar operation Add

			#Play template
			asPlayFile -nocache "pmt/pmt_intercept_countries.html"

		} else {


			if {$operation == "All"} {

				# Display all countries
				tpSetVar operation all

				set countrySql [subst {
					select
						int_country_id as country_id,
						country_string as country_name,
						status
					from
						tPmtIntcptCntry
					order by
						country_string
				}]

			} else {

				# Search countries
				tpSetVar operation srch
				set country_name [string toupper [reqGetArg country_name]]

				set countrySql [subst {
					select
						int_country_id as country_id,
						country_string as country_name,
						status
					from
						tPmtIntcptCntry
					where
						country_string like '${country_name}%'
					order by
						country_string
				}]
			}

			# Execute SQL
			set countryStmt [inf_prep_sql $DB $countrySql]
			set countryRes  [inf_exec_stmt $countryStmt]
			inf_close_stmt $countryStmt

			#Store the country data
			bind_rs  $countryRes COUNTRY country_idx
			db_close $countryRes

			#Play template
			asPlayFile -nocache "pmt/pmt_intercept_countries.html"

			#Cleanup
			catch {unset COUNTRY}
		}
	}


	#
	# Perform action on payment intercept country
	#
	proc do_pmt_intercept_country {} {

		global DB COUNTRY

		#Check we've the appropriate permissions
		if {![op_allowed ManagePmtIntercepts]} {
			err_bind "You do not have permission to amend the country details"
			reqSetArg SubmitName All
			go_pmt_intercept_country
		}

		#Check which operation we're after
		set operation [reqGetArg SubmitName]
		OT_LogWrite 5 " => do_pmt_intercept_country. SubmitName = $operation"

		if {$operation == "Upd"} {

			#Update an existing record
			set name   [string toupper [reqGetArg country_name]]
			set status [reqGetArg status]
			set id     [reqGetArg country_id]

			#Check we have a vaild country name
			if {$name == ""} {
				err_bind "Country name cannot be empty"
				go_pmt_intercept_country
				return
			}

			#Update the record
			set countrySql [subst {
				update
					tPmtIntcptCntry
				set
					country_string = '$name',
					status      = '$status'
				where
					int_country_id = $id}]

			# Execute SQL


			set countryStmt [inf_prep_sql $DB $countrySql]
			inf_exec_stmt $countryStmt
			inf_close_stmt $countryStmt

			#Display country list
			reqSetArg SubmitName All
			go_pmt_intercept_country

		} elseif {$operation == "Add"} {

			#Add new existing record
			set name   [string toupper [reqGetArg country_name]]
			set status [reqGetArg status]

			#Check we have a vaild country name
			if {$name == ""} {
				err_bind "Country name cannot be empty"
				go_pmt_intercept_country
				return
			}

			#Insert the record
			set countrySql [subst {

				Insert into tPmtIntcptCntry
				(
					country_string,
					status
				)
				values
				(
					'$name',
					'$status'
				)
			}]

			# Execute SQL
			set countryStmt [inf_prep_sql $DB $countrySql]
			inf_exec_stmt $countryStmt
			inf_close_stmt $countryStmt

			#Display country list
			reqSetArg SubmitName All
			go_pmt_intercept_country

		} elseif {$operation == "Del"} {

			# Delete record
			set id   [reqGetArg country_id]

			# Delete associated intercepts
			set defnSQL [ subst {

				delete from tPmtIntcptDefn
				where int_country_id = $id
			}]
			set defnStmt [inf_prep_sql $DB $defnSQL]
			inf_exec_stmt $defnStmt
			inf_close_stmt $defnStmt

			# Delete the record
			set countrySql [subst {

				Delete from tPmtIntcptCntry
				where int_country_id = $id
			}]

			# Execute SQL
			set countryStmt [inf_prep_sql $DB $countrySql]
			inf_exec_stmt $countryStmt
			inf_close_stmt $countryStmt

			#Display country list
			reqSetArg SubmitName All
			go_pmt_intercept_country

		} else {

			err_bind "Unknown operation $operation"
			go_pmt_intercept_country
		}
	}

	#
	# Helper method to bind all the data in a recordset into
	# a global with associated template player variables
	#
	# rs   - Recordset to extract data from
	# var  - global used to store data
	# args - the loop counters
	#
	proc bind_rs {rs var args} {

		#Scope the variable
		global $var

		#Store recordset size
		set ${var}(nrows) [db_get_nrows $rs]

		#Cycle over the columns
		foreach colname [db_get_colnames $rs] {

			#Cycle over the rows
			for {set i 0} {$i < [subst $${var}(nrows)]} {incr i} {

				#Store data
				set ${var}($i,$colname) [db_get_col $rs $i $colname]
				OT_LogWrite 10 "Setting ${var}($i,$colname) = [subst $${var}($i,$colname)]"
			}

			#Bind the variable
			tpBindVar $colname $var $colname [join $args]
		}
	}
}


