# ==============================================================
# $Header: /cvsroot-openbet/training/admin/tcl/pmt/pmt_batch.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2006 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::PMT {

asSetAct ADMIN::PMT::GoBatchQry     [namespace code go_batch_qry]
asSetAct ADMIN::PMT::DoBatchSearch  [namespace code do_batch_search]
asSetAct ADMIN::PMT::DoPmtBatch     [namespace code do_pmt_batch]
asSetAct ADMIN::PMT::GoPmtBatch     [namespace code go_pmt_batch]
asSetAct ADMIN::PMT::DoBatchCSV     [namespace code do_batch_csv]


#
# Play the Batch query and generation page
#
proc go_batch_qry args {

	global DB BATCHTYPES

	if {![op_allowed ViewPmtBatches]} {
		err_bind "You do not have permission to view Payment Batches"

	} else {

		set res [_get_batch_types]

		set nrows [db_get_nrows $res]
	
		for {set r 0} {$r < $nrows} {incr r} {
			set BATCHTYPES($r,batch_type) [db_get_col $res $r batch_type]
			set BATCHTYPES($r,batch_desc) [db_get_col $res $r desc]
		}
	
		db_close $res
	
		tpSetVar NumBatches $nrows
	
		tpBindVar batch_type BATCHTYPES batch_type btype_idx
		tpBindVar batch_desc BATCHTYPES batch_desc btype_idx
	}

	asPlayFile -nocache pmt/pmt_batch_qry.html
}


#
# Generate a payement batch.
#
proc do_pmt_batch args {

	global DB USERID

	# If the user doesn't have permission to view batches either they will
	# actually receive that error message. If not, they will get this one.
	if {![op_allowed GeneratePmtBatches]} {
		err_bind "You do not have permission to generate Payment Batches"
		go_batch_qry
		return
	}

	set batch_type [reqGetArg batch_type]

	ob::log::write INFO {do_pmt_batch: batch_type = $batch_type}

	# We can generate batches of all queued payments (%),
	# or only ones which are status "P"=Pending
	set p_status [OT_CfgGet PMT_BATCH_PAY_STATUS P]

	if {$batch_type == {AFFGIB}} {
		set pay_type "Affiliate Payment"

		set sql [subst {
			execute procedure pPmtGenGWTDBatch (
				p_batch_type    = ?,
				p_pay_type      = ?,
				p_status        = '$p_status',
				p_user_id       = ?
			)
		}]

	} elseif {$batch_type == {AFFCHQ}} {
		set pay_type "Affiliate Payment"

		set sql [subst {
			execute procedure pPmtGenAffCHQBatch (
				p_batch_type    = ?,
				p_pay_type      = ?,
				p_status        = '$p_status',
				p_user_id       = ?
			)
		}]

	} elseif {[lsearch [OT_CfgGet PMT_BATCH_TYPES {}] $batch_type] > -1} {
		set pay_type $batch_type

		set sql [subst {
			execute procedure pPmtGenGWTDBatch (
				p_batch_type    = ?,
				p_pay_type      = ?,
				p_status        = '$p_status',
				p_user_id       = ?
			)
		}]

	} else {
		err_bind "Unknown batch type"
		go_batch_qry
		return
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		set res  [inf_exec_stmt $stmt $batch_type $pay_type $USERID]
		inf_close_stmt $stmt

	} msg]} {

		ob::log::write ERROR {do_pmt_batch: Error executing query - $msg}
		err_bind $msg
		go_batch_qry

	} else {

		set pmt_batch_id [db_get_coln $res 0 0]
		db_close $res

		msg_bind "Batch Successfully Created"
		go_pmt_batch $pmt_batch_id
	}
}


#
# Search for batches
#
proc do_batch_search args {

	global DB BATCHLIST

	if {![op_allowed ViewPmtBatches]} {
		err_bind "You do not have permission to view Payment Batches"
		go_batch_qry
		return
	}

	set where [list]

	set pmt_batch_id  [reqGetArg batch_id]  
	set batch_type    [reqGetArg batch_type]

	# If a batch id is provided, go straight to it
	if {$pmt_batch_id != {}} {
		go_pmt_batch $pmt_batch_id
		return
	}

	if {$batch_type != {ANY}} {
		lappend where "b.batch_type = '$batch_type'"
	}

	set batch_date_1     [reqGetArg batch_date_1]
	set batch_date_2     [reqGetArg batch_date_2]
	set batch_date_range [reqGetArg batch_date_range]

	if {$batch_date_range != ""} {
		set now_dt [clock format [clock seconds] -format %Y-%m-%d]
		foreach {Y M D} [split $now_dt -] { break }
		set batch_date_2 "$Y-$M-$D"
		if {$batch_date_range == "TD"} {
			set batch_date_1 "$Y-$M-$D"
		} elseif {$batch_date_range == "CM"} {
			set batch_date_1 "$Y-$M-01"
		} elseif {$batch_date_range == "YD"} {
			set batch_date_1 [date_days_ago $Y $M $D 1]
			set batch_date_2 $batch_date_1
		} elseif {$batch_date_range == "L3"} {
			set batch_date_1 [date_days_ago $Y $M $D 3]
		} elseif {$batch_date_range == "L7"} {
			set batch_date_1 [date_days_ago $Y $M $D 7]
		}
		append batch_date_1 " 00:00:00"
		append batch_date_2 " 23:59:59"
	}

	if {$batch_date_1 != ""} {
		lappend where "b.cr_date >= '$batch_date_1'"
	}
	if {$batch_date_2 != ""} {
		lappend where "b.cr_date <= '$batch_date_2'"
	}

	if {[llength $where]} {
		set where "and [join $where { and }]"
	}

	set sql [subst {
		select
			b.pmt_batch_id,
			b.pay_type,
			b.cr_date,
			t.desc
		from
			tPmtBatch b,
			tPmtBatchType t
		where
			b.batch_type = t.batch_type
			$where
		order by pmt_batch_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	for {set r 0} {$r < $nrows} {incr r} {
		set BATCHLIST($r,batch_id)   [db_get_col $res $r pmt_batch_id]
		set BATCHLIST($r,pay_type)   [db_get_col $res $r pay_type]
		set BATCHLIST($r,cr_date)    [db_get_col $res $r cr_date]
		set BATCHLIST($r,batch_desc) [db_get_col $res $r desc]
	}

	tpSetVar NumBatches $nrows

	tpBindVar batch_id   BATCHLIST batch_id   brows_idx
	tpBindVar pay_type   BATCHLIST pay_type   brows_idx
	tpBindVar cr_date    BATCHLIST cr_date    brows_idx
	tpBindVar batch_desc BATCHLIST batch_desc brows_idx

	asPlayFile -nocache pmt/pmt_batch_list.html

}


#
# Retrieve and display a given batch
#
proc go_pmt_batch args {

	global DB BATCHROWS

	if {![op_allowed ViewPmtBatches]} {
		err_bind "You do not have permission to view Payment Batches"
		go_batch_qry
		return
	}

	if {[llength $args] == 1} {
		set pmt_batch_id [lindex $args 0]
	} else {
		set pmt_batch_id [reqGetArg batch_id]
	}

	tpBindString batch_id $pmt_batch_id

	set sql {
		select
			b.batch_type,
			b.pay_type,
			b.cr_date,
			t.desc
		from
			tPmtBatch b,
			tPmtBatchType t
		where
			b.pmt_batch_id = ?
		and b.batch_type = t.batch_type
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $pmt_batch_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	if {$nrows < 1} {
		ob::log::write 1 "go_pmt_batch: Could not find batch id $pmt_batch_id"
		err_bind "Could not find batch id $pmt_batch_id"
		go_batch_qry
		return
	}

	set batch_type [db_get_col $res 0 batch_type]
	set batch_desc [db_get_col $res 0 desc]
	set pay_type   [db_get_col $res 0 pay_type]
	set cr_date    [db_get_col $res 0 cr_date]

	db_close $res

	tpBindString BatchType $batch_type
	tpBindString BatchDesc $batch_desc
	tpBindString PayType   $pay_type
	tpBindString Date      $cr_date

	if {$batch_type == {AFFGIB} || $batch_type == {AFFCHQ}} {
		set sql {
			select
				a.aff_name as username,
				p.acct_id,
				a.ccy_code,
				p.amount
			from
				tPmtBatchLink l,
				tPmt p,
				tAffAcct a
			where
				l.pmt_batch_id = ?
			and l.pmt_id      = p.pmt_id
			and p.acct_id     = a.acct_id
		}
	} elseif {[lsearch [OT_CfgGet PMT_BATCH_TYPES {}] $batch_type] > -1} {
		set sql {
			select
				c.username,
				p.acct_id,
				a.ccy_code,
				p.amount
			from
				tPmtBatchLink l,
				tPmt p,
				tAcct a,
				tCustomer c
			where
				l.pmt_batch_id = ?
			and l.pmt_id      = p.pmt_id
			and p.acct_id     = a.acct_id
			and c.cust_id     = a.cust_id
		}
	} else {
		err_bind "Unknown batch type"
		go_batch_qry
		return
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $pmt_batch_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	for {set r 0} {$r < $nrows} {incr r} {
		set BATCHROWS($r,username) [db_get_col $res $r username]
		set BATCHROWS($r,acct_id)  [db_get_col $res $r acct_id]
		set BATCHROWS($r,ccy_code) [db_get_col $res $r ccy_code]
		set BATCHROWS($r,amount)   [db_get_col $res $r amount]
	}

	db_close $res

	tpSetVar NumRowsBatch $nrows

	tpBindVar username BATCHROWS username brows_idx
	tpBindVar acct_id  BATCHROWS acct_id  brows_idx
	tpBindVar ccy_code BATCHROWS ccy_code brows_idx
	tpBindVar amount   BATCHROWS amount   brows_idx

	asPlayFile -nocache pmt/pmt_batch.html
}


#
# Retrieve the payment details for all pmt in the batch and generate a csv
#
proc do_batch_csv args {

	global DB PMTDET

	if {![op_allowed ViewPmtBatches]} {
		err_bind "You do not have permission to view Payment Batches"
		go_batch_qry
		return
	}

	set pmt_batch_id [reqGetArg batch_id]
	set batch_type   [reqGetArg batch_type]

	ob::log::write INFO "do_batch_csv: generating csv for batch id $pmt_batch_id"

	if {$batch_type == {AFFGIB} || $batch_type == {AFFCHQ}} {
		set sql_list [aff_batch_details $batch_type]
	} elseif {[lsearch [OT_CfgGet PMT_BATCH_TYPES {}] $batch_type] > -1} {
		set sql_list [gwtd_batch_details $batch_type]
	} else {
		err_bind "Unknown batch type"
		go_pmt_batch $pmt_batch_id
		return
	}

	# First we need to find out how many payments we are expecting
	# We will use this for error checking later on
	set sql [subst {
		select
			count(*)
		from
			tPmtBatchLink
		where
			pmt_batch_id = $pmt_batch_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set pmt_count [db_get_coln $res 0 0]

	# This shouldn't be able to happen unless the wrong batch id is somehow
	# passed through.
	if {$pmt_count < 1} {
		ob::log::write 1 "ERROR: no payments found for batch id $pmt_batch_id"
		err_bind "Error while retreiving batch count"
		go_pmt_batch $pmt_batch_id
		return
	}

	db_close $res

	set PMTDET(pmt_ids)  [list]
	set PMTDET(acct_ids) [list]

	# Now loop through the sql statements and retrieve all the payment details
	foreach sql $sql_list {
		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $pmt_batch_id]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $res]

		for {set r 0} {$r < $nrows} {incr r} {
			set pmt_id   [db_get_col $res $r pmt_id]
			set acct_id  [db_get_col $res $r acct_id]
			set pay_mthd [db_get_col $res $r pay_mthd]

			if {[lsearch $PMTDET(acct_ids) $acct_id] == -1} {
				lappend PMTDET(acct_ids) $acct_id
				set PMTDET($acct_id,pmt_ids) [list]
			}

			# Shouldn't get a pmt_id more than once
			if {[lsearch $PMTDET(pmt_ids) $pmt_id] != -1} {
				ob::log::write 1 "ERROR: pmt id $pmt_id was returned more than once!!"
				err_bind "The same payment was retrieved twice."
				go_batch_qry
				return
			}

			lappend PMTDET(pmt_ids) $pmt_id
			lappend PMTDET($acct_id,pmt_ids) $pmt_id
			set PMTDET($acct_id,$pmt_id,pay_mthd) $pay_mthd

			# The columns will be different depending on the batch type, so we
			# just retrieve the values for all columns.
			foreach col_name [db_get_colnames $res] {
				set PMTDET($acct_id,$pmt_id,$col_name) [db_get_col $res $r $col_name]
			}
		}

		db_close $res
	}

	# If we need to get the totals, then do this now
	# seperate totals are calculated for each currency
	set cur_code 0
	set CCYS_USED [list]
	if {[info exists PMTDET($batch_type,$PMTDET($batch_type,def_headers),totals_sql)]} {
		set sql $PMTDET($batch_type,$PMTDET($batch_type,def_headers),totals_sql)

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $pmt_batch_id]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $res]

		for {set r 0} {$r < $nrows} {incr r} {
			set ccy_code     [db_get_col $res $r ccy_code]
			# if we havent seen this currency before added to the list of seen currencies
			if {![info exists CCYLST($ccy_code)]} {
				# each currency is assigned an integer ID in order to satisfy TP_LOOP
				set CCYLST($ccy_code) $cur_code
				incr cur_code
			}
			set ccy_code $CCYLST($ccy_code)
			set total_amount [format %.2f [db_get_col $res $r amount]]
			set total_count  [db_get_col $res $r count]
			set PMTDET($ccy_code,totalAmount) $total_amount
			set PMTDET($ccy_code,totalCount) $total_count
		}

		#the bind now also depends on the Currency it is associated with
		tpBindVar totalAmount PMTDET totalAmount CCY
		tpBindVar totalCount PMTDET totalCount CCY

		db_close $res
	}

	# Error checking. Need to make sure that we aren't printing out the wrong
	# number of payments.
	# Eg, if a customer has the wrong number of pmt methds we could end up
	# getting multiple rows back when we join on tCustPayMthd, or none at all
	# so payments could be paid twice or skipped
	if {[llength $PMTDET(pmt_ids)] != $pmt_count} {
		ob::log::write 1 "ERROR: wrong number of payments retrieved. Should be $pmt_count found [llength $PMTDET(pmt_ids)]"
		err_bind "The wrong number of payments was retrieved."
		go_batch_qry
		return
	}

	set filename payment_batch_${pmt_batch_id}.csv
	if {[info exists PMTDET($batch_type,$PMTDET($batch_type,def_headers),filename)]} {
		set filename $PMTDET($batch_type,$PMTDET($batch_type,def_headers),filename)
	}

	# Used for the boundaries between different currency file attachments
	set boundary "gc0p4Jq0M2Yt08j"
	tpBufAddHdr "Content-Type" "multipart/mixed;boundary=${boundary}"
	
	# If we have a template to play, we bind up the data, play the template and we're done
	if {[info exists PMTDET($batch_type,$PMTDET($batch_type,def_headers),template)]} {
		foreach acct_id $PMTDET(acct_ids) {
			foreach pmt_id $PMTDET($acct_id,pmt_ids) {
				# get the payments currency
				if {[catch {set CCY_CODE $PMTDET($acct_id,$pmt_id,ccy_code)} msg]} {
					set CCY_CODE ""
				}
				# get the integer id for the currency code needed for TP_LOOP
				if {![info exists CCYLST($CCY_CODE)]} {
					set CCYLST($CCY_CODE) $cur_code
					incr cur_code
				} 
				set CCY_ID $CCYLST($CCY_CODE)
				if {![info exists PMTDET($CCY_ID,ccyline_ix)]} {
					#both remembered for use in creating the multipart page
					lappend CCYS_USED $CCY_ID 
					lappend CCYS_USED $CCY_CODE
					set PMTDET($CCY_ID,ccyline_ix) 0
				}
					
				set pmt_finished 0

				# Need to obey max limits per ccy per pmt
				#
				# When a customer has more than the limit in a single payment,
				# we only pay the limit amount in this pmt and put the rest
				# into another payment line to the customer
				# (hence the while loop and pmt line counter here)
				set pmt_line 1

				while {!$pmt_finished} {
					# Bind up the data

					foreach {header_name type var} $PMTDET($batch_type,$PMTDET($acct_id,$pmt_id,pay_mthd),column_list) {
						switch -- $type {
							{DB}     {set col_value $PMTDET($acct_id,$pmt_id,$var)}
							{STATIC} {set col_value $var}
						}
						
						
						set PMTDET($PMTDET($CCY_ID,ccyline_ix),$CCY_ID,$header_name) $col_value
						if {$header_name == "amount"} {
							set PMTDET($PMTDET($CCY_ID,ccyline_ix),$CCY_ID,$header_name) [format %.2f $col_value]
						}

						if {$PMTDET($CCY_ID,ccyline_ix) == 0} {
							tpBindVar $header_name PMTDET $header_name line_idx CCY
						}
					}

					# Figure out if we need another payment line
					# (If we don't have an amount field then that's a no)
					if {![info exists PMTDET($acct_id,$pmt_id,amount)]} {
						set pmt_finished 1
					} else {
						set ccy_code $PMTDET($acct_id,$pmt_id,ccy_code)

						# Find out the limit in this customer's ccy
						# If it is not defined then we have no limit to worry about
						if {![info exists PMTDET($batch_type,$PMTDET($batch_type,def_headers),$ccy_code)]} {
							OT_LogWrite DEBUG "No ccy limit needed for $ccy_code"
							set pmt_finished 1
						} else {
							set max_amt $PMTDET($batch_type,$PMTDET($batch_type,def_headers),$ccy_code)

							if {$PMTDET($acct_id,$pmt_id,amount) > $max_amt} {
								OT_LogWrite DEBUG "Splitting pmt over multiple lines"
								# Only make the pmt for the max amount, and put the remainder into the next pmt
								set PMTDET($PMTDET($CCY_ID,ccyline_ix),$CCY_ID,amount) $max_amt
								set PMTDET($acct_id,$pmt_id,amount) [expr {$PMTDET($acct_id,$pmt_id,amount) - $max_amt}]

								# Change the pmt_id to have the pmt line counter at the end
								set PMTDET($PMTDET($CCY_ID,ccyline_ix),$CCY_ID,pmt_id) "${pmt_id}-${pmt_line}"
							} else {
								set pmt_finished 1

								# Make sure the final line in a pmt also has the line counter at the end
								if {$pmt_line > 1} {
									# Change the pmt_id to have the pmt line counter at the end
									set PMTDET($PMTDET($CCY_ID,ccyline_ix),$CCY_ID,pmt_id) "${pmt_id}-${pmt_line}"
								}
							}

							incr pmt_line
						}
					}

					incr PMTDET($CCY_ID,ccyline_ix)
				}
			}
		}
		foreach {CCY_ID CCY_CODE} $CCYS_USED {
			# Save each Currency in a seperate file ending in the currency code
			#
			tpBufWrite "--${boundary}\nContent-Type: text/plain; name=${filename}.${CCY_CODE}\nContent-Disposition: attachment; filename=\"${filename}.${CCY_CODE}\n\n"
			OT_LogWrite INFO "CCY_CCYS_USED: --${CCY_CODE}--"
			tpSetVar CCY $CCY_ID
			tpSetVar num_lines $PMTDET($CCY_ID,ccyline_ix)
			OT_LogWrite INFO "CCY_num_lines: $PMTDET($CCY_ID,ccyline_ix)"
			asPlayFile -nocache $PMTDET($batch_type,$PMTDET($batch_type,def_headers),template)
		}
		tpBufWrite "--${boundary}--"
		return
	}

	# Get the column separator
	set colseparator ","
	if {[info exists PMTDET($batch_type,$PMTDET($batch_type,def_headers),colseparator)]} {
		set colseparator $PMTDET($batch_type,$PMTDET($batch_type,def_headers),colseparator)
	}

	# Get the header for the csv files
	set colheaders 1
	if {[info exists PMTDET($batch_type,$PMTDET($batch_type,def_headers),colheaders)]} {
		set colheaders $PMTDET($batch_type,$PMTDET($batch_type,def_headers),colheaders)
	}
	if {$colheaders} {
		set seperator ""
		foreach {header_name type var} $PMTDET($batch_type,$PMTDET($batch_type,def_headers),column_list) {
			set headerline "${header_line}${sepertor}${header_name}"
			set seperator $colseparator
		}
	}

	# Might as well print out the lines in some kind of order
	set PMTDET(acct_ids) [lsort -integer $PMTDET(acct_ids)]

	# Write out the data for the csv
	# Each currency goes in a seperate file
	global LINE_DATA
	foreach acct_id $PMTDET(acct_ids) {
		foreach pmt_id $PMTDET($acct_id,pmt_ids) {
			# get the payments currency
			if {[catch {set CCY_CODE $PMTDET($acct_id,$pmt_id,ccy_code)} msg]} {
				set CCY_CODE ""
			}
			# get the integer id for the currency code needed for a possible TP_LOOP used above
			if {![info exists CCYLST($CCY_CODE)]} {
				set CCYLST($CCY_CODE) $cur_code				
				incr cur_code
			} 
			set CCY_ID $CCYLST($CCY_CODE)
			if {[lsearch $CCYS_USED $CCY_CODE] == -1} {
				#both remembered for use in creating the multipart page
				lappend CCYS_USED $CCY_ID 
				lappend CCYS_USED $CCY_CODE
			}
			set line [list]
			foreach {header_name type var} $PMTDET($batch_type,$PMTDET($acct_id,$pmt_id,pay_mthd),column_list) {
				switch -- $type {
					{DB}     {set col_value $PMTDET($acct_id,$pmt_id,$var)}
					{STATIC} {set col_value $var}
				}
				lappend line [escape_csv $col_value]
			}
			set line [join $line $colseparator]
			set nl "\n"
			if {![info exists LINE_DATA($CCY_ID)]} {
				if {$colheaders} {
					set LINE_DATA($CCY_ID) $headerline
				} else {
					set LINE_DATA($CCY_ID) ""
					set nl ""
				}
			}
			set LINE_DATA($CCY_ID) "$LINE_DATA($CCY_ID)${nl}${line}"
		}
	}

	foreach {CCY_ID CCY_CODE} $CCYS_USED {
		# Save each Currency in a seperate file ending in the currency code
		#
		tpBufWrite "--${boundary}\nContent-Type: text/plain; name=${filename}.${CCY_CODE}\nContent-Disposition: attachment; filename=\"${filename}.${CCY_CODE}\n\n"
		OT_LogWrite INFO "CCY_CCYS_USED: --${CCY_CODE}--"
		tpBufWrite "$LINE_DATA($CCY_ID)"
		}
	tpBufWrite "--${boundary}--"
	catch {unset LINE_DATA}
}

proc _get_batch_types {} {
	global DB

	set stmt [inf_prep_sql $DB {
		select
			batch_type,
			desc
		from
			tPmtBatchType
                }]

	set res [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	return $res
}


#
# This returns the sql that needs to be run to retrieve the affiliate payment
# details. It also defines the structure that the csv file will have.
#
proc aff_batch_details {batch_type} {

	global DB PMTDET

	# def_headers represents a default pmt mthd that can be used to retrieve
	# the headers for the csv file. It will be different for each batch type
	set PMTDET(AFFGIB,def_headers) "CHQ"

	set PMTDET(AFFGIB,CHQ,column_list) [list \
		{AFF USERNAME}                DB      aff_name \
		{AFF ACCOUNT ID}              DB      acct_id \
		{AREA}                        DB      area_code \
		{VOUCHER BATCH NUMBER}        STATIC  {} \
		{ADDRESS 1}                   DB      address_1 \
		{ADDRESS 2}                   DB      address_2 \
		{CITY}                        DB      city \
		{STATE}                       DB      state \
		{POST CODE}                   DB      post_code \
		{COUNTRY}                     DB      country \
		{AFFILIATE CONTACT NAME}      DB      contact_name \
		{AFFILIATE EMAIL ADDRESS}     DB      email \
		{AFFILIATE LEVEL}             STATIC  {} \
		{NAME (ON BANK ACCOUNT)}      DB      payee \
		{TAX CLASS NUMBER}            STATIC  {} \
		{TRADE REGISTRATION NUMBER}   STATIC  {} \
		{VAT ID}                      DB      vat_number \
		{VOUCHER AMOUNT}              DB      amount \
		{DESTINATION SORT CODE}       STATIC  {} \
		{DESTINATION ACCOUNT NUMBER}  STATIC  {} \
		{BANK NAME}                   STATIC  {} \
		{PAYMENT METHOD}              STATIC  {Cheque}]

	set PMTDET(AFFGIB,BACS,column_list) [list \
		{AFF USERNAME}                DB      aff_name \
		{AFF ACCOUNT ID}              DB      acct_id \
		{AREA}                        DB      area_code \
		{VOUCHER BATCH NUMBER}        STATIC  {} \
		{ADDRESS 1}                   DB      address_1 \
		{ADDRESS 2}                   DB      address_2 \
		{CITY}                        DB      city \
		{STATE}                       DB      state \
		{POST CODE}                   DB      post_code \
		{COUNTRY}                     DB      country \
		{AFFILIATE CONTACT NAME}      DB      contact_name \
		{AFFILIATE EMAIL ADDRESS}     DB      email \
		{AFFILIATE LEVEL}             STATIC  {} \
		{NAME (ON BANK ACCOUNT)}      DB      payee \
		{TAX CLASS NUMBER}            STATIC  {} \
		{TRADE REGISTRATION NUMBER}   STATIC  {} \
		{VAT ID}                      DB      vat_number \
		{VOUCHER AMOUNT}              DB      amount \
		{DESTINATION SORT CODE}       DB      sort_code \
		{DESTINATION ACCOUNT NUMBER}  DB      acct_no \
		{BANK NAME}                   DB      bank_name \
		{PAYMENT METHOD}              STATIC  {BACS}]

	set PMTDET(AFFCHQ,def_headers) "CHQ"
	# The affiliate cheque batch for .com will have the same fields as the one
	# from gib, so we can reuse it.
	set PMTDET(AFFCHQ,CHQ,column_list) $PMTDET(AFFGIB,CHQ,column_list)

	set sql_list [list]

	# Affiliate payments from gib go through as GWTD payments. We will need to
	# find the actual payment method through which the affiliate will be paid.
	if {$batch_type == {AFFGIB}} {
		# Sql to get cheque payments
		lappend sql_list {
			select
				p.pmt_id,
				p.amount,
				aa.aff_acct_id as acct_id,
				aa.aff_name,
				aa.vat_number,
				r.fname || " " || r.lname as contact_name,
				r.email,
				m.pay_mthd,
				q.payee         as payee,
				q.addr_street_1 as address_1,
				q.addr_street_2 as address_2,
				q.addr_street_3 as state,
				q.addr_city     as city,
				q.addr_postcode as post_code,
				q.country_code  as country,
				pa.area_code
			from
				tPmtBatchLink l,
				tPmt p,
				tPmtGWTD g,
				tAcct ac,
				tCustomerReg r,
				tCustPayMthd m,
				tCPMChq q,
				tAffAcct aa,
				tPmtAff pa
			where
				l.pmt_batch_id = ?
			and l.pmt_id      = p.pmt_id
			and p.pmt_id      = g.pmt_id
			and p.acct_id     = ac.acct_id
			and ac.cust_id    = r.cust_id
			and ac.cust_id    = m.cust_id
			and m.status      = 'A'
			and m.cpm_id      = q.cpm_id
			and ac.acct_id    = aa.acct_id
			and p.pmt_id      = pa.pmt_id
		}

		# Sql to get BACS payments
		lappend sql_list {
			select
				p.pmt_id,
				p.amount,
				aa.aff_acct_id as acct_id,
				aa.aff_name,
				aa.vat_number,
				r.fname || " " || r.lname as contact_name,
				r.email,
				m.pay_mthd,
				r.addr_street_1  as address_1,
				r.addr_street_2  as address_2,
				r.addr_street_3  as state,
				r.addr_city      as city,
				r.addr_postcode  as post_code,
				r.addr_country   as country,
				b.bank_name      as bank_name,
				b.bank_acct_name as payee,
				b.bank_acct_no   as acct_no,
				b.bank_sort_code as sort_code,
				pa.area_code
			from
				tPmtBatchLink l,
				tPmt p,
				tPmtGWTD g,
				tAcct ac,
				tCustomerReg r,
				tCustPayMthd m,
				tCPMBankXfer b,
				tAffAcct aa,
				tPmtAff pa
			where
				l.pmt_batch_id = ?
			and l.pmt_id      = p.pmt_id
			and p.pmt_id      = g.pmt_id
			and p.acct_id     = ac.acct_id
			and ac.cust_id    = r.cust_id
			and ac.cust_id    = m.cust_id
			and m.status      = 'A'
			and m.cpm_id      = b.cpm_id
			and ac.acct_id    = aa.acct_id
			and p.pmt_id      = pa.pmt_id
		}

	# Affiliate cheque payments (from .com) go in as cheque payments straight off
	# if $batch_type == AFFCHQ
	} else {
		lappend sql_list {
			select
				p.pmt_id,
				p.amount,
				aa.aff_acct_id as acct_id,
				aa.aff_name,
				aa.vat_number,
				r.fname || " " || r.lname as contact_name,
				r.email,
				"CHQ" as pay_mthd,
				q.payee         as payee,
				q.addr_street_1 as address_1,
				q.addr_street_2 as address_2,
				q.addr_street_3 as state,
				q.addr_city     as city,
				q.addr_postcode as post_code,
				q.country_code  as country,
				pa.area_code
			from
				tPmtBatchLink l,
				tPmt p,
				tPmtChq pq,
				tAcct ac,
				tCustomerReg r,
				tCPMChq q,
				tAffAcct aa,
				tPmtAff pa
			where
				l.pmt_batch_id = ?
			and l.pmt_id      = p.pmt_id
			and p.pmt_id      = pq.pmt_id
			and p.acct_id     = ac.acct_id
			and ac.cust_id    = r.cust_id
			and p.cpm_id      = q.cpm_id
			and ac.acct_id    = aa.acct_id
			and p.pmt_id      = pa.pmt_id
		}
	}

	return $sql_list
}


#
# This returns the sql that needs to be run to retrieve the batch payment
# details. It also defines the structure that the csv file will have.
#
proc gwtd_batch_details {batch_type} {

	global PMTDET

	if {[info exists PMTDET($batch_type,$batch_type,sql_list)]} {
		return $PMTDET($batch_type,$batch_type,sql_list)
	}

	OT_LogWrite DEBUG "Setting up pmt batch info for GWTD"

	# def_headers represents a default pmt mthd that can be used to retrieve
	# the headers for the csv file. It will be different for each batch type
	set PMTDET($batch_type,def_headers) $batch_type

	set PMTDET($batch_type,$batch_type,column_list) [list \
		{USERNAME}                    DB      username \
		{ACCOUNT ID}                  DB      acct_id \
		{VOUCHER BATCH NUMBER}        STATIC  {} \
		{PAY TYPE}                    DB      pay_mthd \
		{EXT EMAIL ADDR}              DB      ext_email_addr \
		{EXT ACCT NO}                 DB      ext_acct_no \
		{ADDRESS 1}                   DB      address_1 \
		{ADDRESS 2}                   DB      address_2 \
		{CITY}                        DB      city \
		{STATE}                       DB      state \
		{POST CODE}                   DB      post_code \
		{COUNTRY}                     DB      country \
		{EMAIL ADDRESS}               DB      email \
		{TAX CLASS NUMBER}            STATIC  {} \
		{TRADE REGISTRATION NUMBER}   STATIC  {} \
		{VOUCHER AMOUNT}              DB      amount \
		{DESTINATION SORT CODE}       STATIC  {} \
		{DESTINATION ACCOUNT NUMBER}  STATIC  {} \
		{BANK NAME}                   STATIC  {} \
		{PAYMENT METHOD}              STATIC  $batch_type]

	set sql_list [list]

	if {1} {
		# Sql to get payments
		lappend sql_list {
			select
				p.pmt_id,
				p.amount,
				g.pay_type as pay_mthd,
				g.blurb as ext_email_addr,
				g.extra_info as ext_acct_no,
				ac.acct_id,
				ac.ccy_code,
				c.username,
				r.fname,
				r.lname,
				r.email,
				r.addr_street_1 as address_1,
				r.addr_street_2 as address_2,
				r.addr_street_3 as city,
				cs.state,
				r.addr_postcode as post_code,
				r.addr_country as country
			from
				tPmtBatchLink l,
				tPmt p,
				tPmtGWTD g,
				tAcct ac,
				tCustomer c,
				tCustomerReg r,
				outer tCountryState cs
			where
				l.pmt_batch_id = ?
			and l.pmt_id      = p.pmt_id
			and p.pmt_id      = g.pmt_id
			and p.acct_id     = ac.acct_id
			and ac.cust_id    = c.cust_id
			and c.cust_id     = r.cust_id
			and r.addr_state_id = id
		}
	}

	set PMTDET($batch_type,$batch_type,sql_list) $sql_list

	return $sql_list
}

#
# Procedure to correctly escape csv, taken from
# dev_utils/tcl/unload_xlations.tcl
#
proc escape_csv {s} {
	set s [string map [list \" \"\"] $s]
	if {[string first "," $s] != -1 || \
		[string first "\n" $s] != -1 || \
		[string first \" $s] != -1} {
		return \"$s\"
	} else {
		return $s
	}
}

proc lpad {str lim {char " "}} {
	set l [string length $str]
	if {$l < $lim} {
		return "[string repeat $char [expr $lim - $l]]$str"
	} else {
		return $str
	}
}
}
