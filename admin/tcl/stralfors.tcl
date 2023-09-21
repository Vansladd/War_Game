# (C) 2005 Orbis Technology Ltd. All rights reserved.
#  $Id: stralfors.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#  Stralfors
#  Stralfors welcome pack flags, display/edit/csv production
#
# Namespace Variables
#
namespace eval ADMIN::STRALFORS {
	asSetAct ADMIN::STRALFORS::GoStralfors          [namespace code go_stralfors]
	asSetAct ADMIN::STRALFORS::DoStralfors          [namespace code do_stralfors]
}



# go_stralfors
# Plays the standard Stralfors welcome packs export page
proc ADMIN::STRALFORS::go_stralfors {} {

	bind_extraction_list
	bind_exception_list

	asPlayFile -nocache stralfors/stralfors.html
}



# do_export_csv
# Exports the extraction and exception lists to CSV files
#
proc ADMIN::STRALFORS::do_export_csv {{extract 1} {exception 0}} {

	global DB CHARSET STRALFORS_EXTRACT STRALFORS_EXCEPTION
	set cust_id_list [list -1]

	ob_log::write INFO {ADMIN::STRALFORS::do_export_csv}

	if {$extract} {
		bind_extraction_list 1 0
		set nr_rows $STRALFORS_EXTRACT(nrows)
		set filename "stralfors_extract_[clock format [clock seconds] -format %Y%m%d].csv"
	} elseif {$exception} {
		bind_exception_list 1 0
		set nr_rows $STRALFORS_EXCEPTION(nrows)
		set filename "stralfors_exception_[clock format [clock seconds] -format %Y%m%d].csv"
	}

	ob_db::begin_tran
	for {set r 0} {$r < $nr_rows} {incr r} {
		if {$extract} {
			lappend cust_id_list $STRALFORS_EXTRACT($r,cust_id)
		} elseif {$exception} {
			lappend cust_id_list $STRALFORS_EXCEPTION($r,cust_id)
		}
	}

	regsub -all { } $cust_id_list {,} cust_id_list

	# Set Stralfors flag of exported customers to 'U'
	set stmt [inf_prep_sql $DB [subst {
		update
			tCustomerFlag
		set
			flag_value = 'U'
		where
			cust_id in ($cust_id_list)
			and flag_name = ?
	}]]

	set rs [inf_exec_stmt $stmt [OT_CfgGet STRALFORS_FLAG_NAME "Stralfors"]]

	inf_close_stmt $stmt

	# Set their exported date to the current time and their Include status to No
	set stmt [inf_prep_sql $DB [subst {
		update
			tCustStralfor
		set
			exported = 'Y',
			export_date = current,
			include = 'N'
		where
			cust_id in ($cust_id_list)
	}]]
		
	set rs [inf_exec_stmt $stmt $cust_id_list]

	inf_close_stmt $stmt

	tpBufAddHdr "Content-Type"  "text/csv; charset=$CHARSET"
	tpBufAddHdr "Content-Disposition" "filename=$filename;"

	if {$extract} {
		asPlayFile -nocache stralfors/extract_file.csv
	} elseif {$exception} {
		asPlayFile -nocache stralfors/exception_file.csv
	}

	ob_db::commit_tran
	db_close $rs
}



# bind_extraction_list
# Binds the list of customers who will be extracted to the Stralfors CSV file
# included_only - only bind the customers who are set to be included
# 
proc ADMIN::STRALFORS::bind_extraction_list {{included_only 0} {sort 0}} {

	global DB STRALFORS_EXTRACT

	set extra_where ""

	# Record whether the list is currently sorted
	if {[info exists STRALFORS_EXTRACT(sorted)]} {
		set sort $STRALFORS_EXTRACT(sorted)
	}

	if {$included_only} {
		set extra_where "and s.include = 'Y'"
	}
	if {$sort} {
		set extra_where "$extra_where order by s.include desc, s.print_code, s.account_type, s.letter, s.tel_no, s.bus_cond"
		set STRALFORS_EXTRACT(sorted) 1
	} else {
		set extra_where "$extra_where order by s.print_code, s.account_type, s.letter, s.tel_no, s.bus_cond"
	}

	# Get all customers who have a Stralfors code that is tagged for export, but
	# not those whose Stralfors code begins with 0, whose address line 1 is empty
	# or who are self-excluded.
	set stmt [inf_prep_sql $DB "
		select
			c.cust_id,
			c.acct_no,
			r.title,
			r.fname,
			r.lname,
			r.addr_street_1,
			r.addr_street_2,
			r.addr_street_3,
			r.addr_city,
			r.addr_street_4,
			r.addr_postcode,
			s.print_code,
			s.account_type,
			s.letter,
			s.tel_no,
			s.bus_cond,
			s.include,
			a.credit_limit,
			p.security_number
		from
			tCustStralfor s,
			tCustomer c,
			tCustomerReg r,
			tCustomerFlag f,
			tAcct a,
			outer tCPMShop p
		where
			s.cust_id = r.cust_id
			and s.stralfor_id = (select
										max(s2.stralfor_id)
									from
										tCustStralfor s2
									where
										s2.cust_id = c.cust_id)
			and r.cust_id = c.cust_id
			and c.cust_id = f.cust_id
			and f.cust_id = a.cust_id
			and a.cust_id = p.cust_id
			and f.flag_name = ?
			and f.flag_value = 'Y'
			and s.print_code <> '0'
			and r.addr_street_1 <> ''
			and not exists (
				select 
					l.cust_id 
				from 
					tCustLimits l 
				where 
					l.cust_id = c.cust_id 
					and l.limit_type = 'self_excl' 
					and l.from_date <= CURRENT and l.to_date >= CURRENT
			)
			$extra_where
	"]

	set rs [inf_exec_stmt $stmt [OT_CfgGet STRALFORS_FLAG_NAME "Stralfors"]]
	inf_close_stmt $stmt

	set STRALFORS_EXTRACT(nrows) [db_get_nrows $rs]

	for {set r 0} {$r < $STRALFORS_EXTRACT(nrows)} {incr r} {
		set STRALFORS_EXTRACT($r,cust_id)         [db_get_col $rs $r cust_id]
		set STRALFORS_EXTRACT($r,acct_no)         [string toupper [db_get_col $rs $r acct_no]]
		set STRALFORS_EXTRACT($r,title)           [string toupper [db_get_col $rs $r title]]
		set STRALFORS_EXTRACT($r,fname)           [string toupper [db_get_col $rs $r fname]]
		set STRALFORS_EXTRACT($r,lname)           [string toupper [db_get_col $rs $r lname]]

		set addr "[db_get_col $rs $r addr_street_1], [db_get_col $rs $r addr_street_2], [db_get_col $rs $r addr_street_3]"
		set STRALFORS_EXTRACT($r,addr)             [string toupper $addr]

		set STRALFORS_EXTRACT($r,addr1)            [string toupper [db_get_col $rs $r addr_street_1]]
		set STRALFORS_EXTRACT($r,addr2)            [string toupper [db_get_col $rs $r addr_street_2]]
		set STRALFORS_EXTRACT($r,addr3)            [string toupper [db_get_col $rs $r addr_street_3]]

		# Strip trailing commas from address
		regsub -all {, ,} $STRALFORS_EXTRACT($r,addr) {,} STRALFORS_EXTRACT($r,addr)
		regsub {,[ ]*$} $STRALFORS_EXTRACT($r,addr) {} STRALFORS_EXTRACT($r,addr)
	
		set STRALFORS_EXTRACT($r,city)            [string toupper [db_get_col $rs $r addr_city]]
		set STRALFORS_EXTRACT($r,county)          [string toupper [db_get_col $rs $r addr_street_4]]
		set STRALFORS_EXTRACT($r,postcode)        [string toupper [db_get_col $rs $r addr_postcode]]
		
		if {[db_get_col $rs $r include] eq "Y"} { 
			set STRALFORS_EXTRACT($r,include) "checked" 
		} else { 
			set STRALFORS_EXTRACT($r,include) "" 
		} 

		set stralfors_code "[db_get_col $rs $r print_code][db_get_col $rs $r account_type][db_get_col $rs $r letter][db_get_col $rs $r tel_no][db_get_col $rs $r bus_cond]"
		set STRALFORS_EXTRACT($r,stralfors_code)  [string toupper $stralfors_code]

		set STRALFORS_EXTRACT($r,credit_limit)    [db_get_col $rs $r credit_limit]
		set STRALFORS_EXTRACT($r,security_number) [db_get_col $rs $r security_number]
	}

	tpBindVar CustId STRALFORS_EXTRACT cust_id stral_extract_idx
	tpBindVar AcctNo STRALFORS_EXTRACT acct_no stral_extract_idx
	tpBindVar Title STRALFORS_EXTRACT title stral_extract_idx
	tpBindVar FName STRALFORS_EXTRACT fname stral_extract_idx
	tpBindVar LName STRALFORS_EXTRACT lname stral_extract_idx
	tpBindVar Addr STRALFORS_EXTRACT addr stral_extract_idx
	tpBindVar Addr1 STRALFORS_EXTRACT addr1 stral_extract_idx
	tpBindVar Addr2 STRALFORS_EXTRACT addr2 stral_extract_idx
	tpBindVar Addr3 STRALFORS_EXTRACT addr3 stral_extract_idx
	tpBindVar City STRALFORS_EXTRACT city stral_extract_idx
	tpBindVar County STRALFORS_EXTRACT county stral_extract_idx
	tpBindVar Postcode STRALFORS_EXTRACT postcode stral_extract_idx
	tpBindVar Include STRALFORS_EXTRACT include stral_extract_idx
	tpBindVar StralCode STRALFORS_EXTRACT stralfors_code stral_extract_idx
	tpBindVar CreditLimit STRALFORS_EXTRACT credit_limit stral_extract_idx
	tpBindVar SecNumber STRALFORS_EXTRACT security_number stral_extract_idx

	tpSetVar NumExtract $STRALFORS_EXTRACT(nrows)

	db_close $rs
}



# bind_exception_list
# Binds the list of customers who have the Stralfors code but will not be extracted 
# to the Stralfors CSV file
# included_only - only bind the customers who are set to be included
# 
proc ADMIN::STRALFORS::bind_exception_list {{included_only 0} {sort 0}} {

	global DB STRALFORS_EXCEPTION

	set extra_where ""

	# Record whether the list is currently sorted
	if {[info exists STRALFORS_EXCEPTION(sorted)]} {
		set sort $STRALFORS_EXCEPTION(sorted)
	}

	if {$included_only} {
		set extra_where "and s.include = 'Y'"
	}
	if {$sort} {
		set extra_where "$extra_where order by s.include desc, s.print_code, s.account_type, s.letter, s.tel_no, s.bus_cond"
		set STRALFORS_EXCEPTION(sorted) 1
	} else {
		set extra_where "$extra_where order by s.print_code, s.account_type, s.letter, s.tel_no, s.bus_cond"
	}

	# Get all customers who have a Stralfors code that is tagged for export, but
	# either their Stralfors code begins with 0, their address line 1 is empty
	# or they are self-excluded.
	set stmt [inf_prep_sql $DB "
		select
			c.cust_id,
			c.acct_no,
			r.title,
			r.fname,
			r.lname,
			r.addr_street_1,
			r.addr_street_2,
			r.addr_street_3,
			r.addr_city,
			r.addr_street_4,
			r.addr_postcode,
			s.print_code,
			s.account_type,
			s.letter,
			s.tel_no,
			s.bus_cond,
			s.include,
			a.credit_limit,
			p.security_number
		from
			tCustStralfor s,
			tCustomer c,
			tCustomerReg r,
			tCustomerFlag f,
			tAcct a,
			outer tCPMShop p
		where
			s.cust_id = r.cust_id
			and s.stralfor_id = (select
										max(s2.stralfor_id)
									from
										tCustStralfor s2
									where
										s2.cust_id = c.cust_id)
			and r.cust_id = c.cust_id
			and c.cust_id = f.cust_id
			and f.cust_id = a.cust_id
			and a.cust_id = p.cust_id
			and f.flag_name = ?
			and f.flag_value = 'Y'
			and (
				s.print_code = '0'
				or r.addr_street_1 = ''
				or r.addr_street_1 is null
				or exists (
					select 
						l.cust_id 
					from 
						tCustLimits l 
					where 
						l.cust_id = c.cust_id 
						and l.limit_type = 'self_excl' 
						and l.from_date <= CURRENT and l.to_date >= CURRENT
				)
			)
			$extra_where
	"]

	set rs [inf_exec_stmt $stmt [OT_CfgGet STRALFORS_FLAG_NAME "Stralfors"]]
	inf_close_stmt $stmt

	set STRALFORS_EXCEPTION(nrows) [db_get_nrows $rs]

	for {set r 0} {$r < $STRALFORS_EXCEPTION(nrows)} {incr r} {
		set STRALFORS_EXCEPTION($r,cust_id)        [db_get_col $rs $r cust_id]
		set STRALFORS_EXCEPTION($r,acct_no)        [string toupper [db_get_col $rs $r acct_no]]
		set STRALFORS_EXCEPTION($r,title)          [string toupper [db_get_col $rs $r title]]
		set STRALFORS_EXCEPTION($r,fname)          [string toupper [db_get_col $rs $r fname]]
		set STRALFORS_EXCEPTION($r,lname)          [string toupper [db_get_col $rs $r lname]]

		set addr "[db_get_col $rs $r addr_street_1], [db_get_col $rs $r addr_street_2], [db_get_col $rs $r addr_street_3]"
		set STRALFORS_EXCEPTION($r,addr)          [string toupper $addr]
	
		set STRALFORS_EXCEPTION($r,addr1)          [string toupper [db_get_col $rs $r addr_street_1]]
		set STRALFORS_EXCEPTION($r,addr2)          [string toupper [db_get_col $rs $r addr_street_2]]
		set STRALFORS_EXCEPTION($r,addr3)          [string toupper [db_get_col $rs $r addr_street_3]]

		# Strip trailing commas from address
		regsub -all {, ,} $STRALFORS_EXCEPTION($r,addr) {,} STRALFORS_EXCEPTION($r,addr)
		regsub {,[ ]*$} $STRALFORS_EXCEPTION($r,addr) {} STRALFORS_EXCEPTION($r,addr)
	
		set STRALFORS_EXCEPTION($r,city)           [string toupper [db_get_col $rs $r addr_city]]
		set STRALFORS_EXCEPTION($r,county)         [string toupper [db_get_col $rs $r addr_street_4]]
		set STRALFORS_EXCEPTION($r,postcode)       [string toupper [db_get_col $rs $r addr_postcode]]

		if {[db_get_col $rs $r include] eq "Y"} { 
			set STRALFORS_EXCEPTION($r,include) "checked" 
		} else { 
			set STRALFORS_EXCEPTION($r,include) "" 
		} 

		set stralfors_code "[db_get_col $rs $r print_code][db_get_col $rs $r account_type][db_get_col $rs $r letter][db_get_col $rs $r tel_no][db_get_col $rs $r bus_cond]"
		set STRALFORS_EXCEPTION($r,stralfors_code)  [string toupper $stralfors_code]

		set STRALFORS_EXCEPTION($r,credit_limit)    [db_get_col $rs $r credit_limit]
		set STRALFORS_EXCEPTION($r,security_number) [db_get_col $rs $r security_number]
	}

	tpBindVar ExcCustId STRALFORS_EXCEPTION cust_id stral_exception_idx
	tpBindVar ExcAcctNo STRALFORS_EXCEPTION acct_no stral_exception_idx
	tpBindVar ExcTitle STRALFORS_EXCEPTION title stral_exception_idx
	tpBindVar ExcFName STRALFORS_EXCEPTION fname stral_exception_idx
	tpBindVar ExcLName STRALFORS_EXCEPTION lname stral_exception_idx
	tpBindVar ExcAddr STRALFORS_EXCEPTION addr stral_exception_idx
	tpBindVar ExcAddr1 STRALFORS_EXCEPTION addr1 stral_exception_idx
	tpBindVar ExcAddr2 STRALFORS_EXCEPTION addr2 stral_exception_idx
	tpBindVar ExcAddr3 STRALFORS_EXCEPTION addr3 stral_exception_idx
	tpBindVar ExcCity STRALFORS_EXCEPTION city stral_exception_idx
	tpBindVar ExcCounty STRALFORS_EXCEPTION county stral_exception_idx
	tpBindVar ExcPostcode STRALFORS_EXCEPTION postcode stral_exception_idx
	tpBindVar ExcInclude STRALFORS_EXCEPTION include stral_exception_idx
	tpBindVar ExcStralCode STRALFORS_EXCEPTION stralfors_code stral_exception_idx
	tpBindVar ExcCreditLimit STRALFORS_EXCEPTION credit_limit stral_exception_idx
	tpBindVar ExcSecNumber STRALFORS_EXCEPTION security_number stral_exception_idx

	tpSetVar NumException $STRALFORS_EXCEPTION(nrows)

	db_close $rs
}



# overide_code
# procedure for getting value of overide code, given type and the value of type
proc ADMIN::STRALFORS::overide_code {type user_val} {
	set types "${type}${user_val}"
	set overideVal [reqGetArg $types]
	return $overideVal
}



# do_stralfors
# general Stralfors procedure for stralfors form submissions
proc ADMIN::STRALFORS::do_stralfors args {

	global STRALFORS_EXTRACT STRALFORS_EXCEPTION

	set submit         [reqGetArg SubmitName]

	# Did the user come here using the link from the Exceptions/Extractions
	# screen to the Customer Details screen?
	set from_stralfors [reqGetArg FromStralfors]
	if {$from_stralfors == ""} {
		set from_stralfors 0
	}

	if {$submit == "ExportExtractionListCSV"} {
		do_export_csv 1 0
		return
	} elseif {$submit == "ExportExceptionListCSV"} {
		do_export_csv 0 1
		return
	} elseif {$submit == "EditCode"} {
		edit_code
		return
	} elseif {$submit == "UpdateFlags"} {
		update_flags
		return
	} elseif {$submit == "SaveFlags"} {
		save_flags
		return
	} elseif {$submit == "Add Stralfor"} {
		add_flags
		return
	} elseif {$submit == "Back"} {
		back_action
		return
	} elseif {$submit == "ReplaceCard"} {
		replace_card
		if {$from_stralfors} {
			go_stralfors
		} else {
			ADMIN::CUST::go_cust
			return
		}
	} elseif {$submit == "ReplaceWelcomePack"} {
		replace_welcome_pack
		if {$from_stralfors} {
			go_stralfors
		} else {
			ADMIN::CUST::go_cust
			return
		}
	} elseif {$submit == "CancelWelcomePack"} {
		cancel_welcome_pack
		if {$from_stralfors} {
			go_stralfors
		} else {
			ADMIN::CUST::go_cust
			return
		}
	} elseif {$submit == "UpdateIncludeStatus"} {
		bind_extraction_list
		update_include_status STRALFORS_EXTRACT
		return
	} elseif {$submit == "UpdateExcIncludeStatus"} {
		bind_exception_list
		update_include_status STRALFORS_EXCEPTION 0
		return
	} elseif {$submit == "SortByIncluded"} {
		sort_by_included "extract"
		return
	} elseif {$submit == "ExcSortByIncluded"} {
		sort_by_included "exception"
		return
	}
}



# update_include_status
# According to what checkboxes the user checks, sets the customers to Included in
# the extraction list
#
proc ADMIN::STRALFORS::update_include_status {full_cust_list {is_extraction_list 1}} {

	global DB

	ob_log::write INFO {ADMIN::STRALFORS::update_include_status}

	set excl_cust_id_list [list]

	upvar $full_cust_list cust_list

	# Get the lists of included and excluded customers
	if {$is_extraction_list} {
		set incl_cust_id_list [reqGetArgs included_cust]
	} else {
		set incl_cust_id_list [reqGetArgs exc_included_cust]
	}

	for {set r 0} {$r < $cust_list(nrows)} {incr r} {
		set cust_id $cust_list($r,cust_id)
		if {[lsearch -integer -exact $incl_cust_id_list $cust_id] == -1} {
			lappend excl_cust_id_list $cust_id
		}
	}
		
	# Format the lists for SQL
	regsub -all { } $incl_cust_id_list {,} incl_cust_id_list
	regsub -all { } $excl_cust_id_list {,} excl_cust_id_list

	# Update the DB
	if {[llength $incl_cust_id_list] > 0} {
		set stmt [inf_prep_sql $DB [subst {
			update
				tCustStralfor
			set
				include = 'Y'
			where
				cust_id in ($incl_cust_id_list)
		}]]
		set rs [inf_exec_stmt $stmt]
		inf_close_stmt $stmt
	}

	if {[llength $excl_cust_id_list] > 0} {
		set stmt [inf_prep_sql $DB [subst {
			update
				tCustStralfor
			set
				include = 'N'
			where
				cust_id in ($excl_cust_id_list)
		}]]
		set rs [inf_exec_stmt $stmt]
		inf_close_stmt $stmt
	}

	db_close $rs

	ADMIN::STRALFORS::go_stralfors
}


# sort_by_included
# Sort the list of customers by whether they are set to be included or not.
#
proc ADMIN::STRALFORS::sort_by_included {type} {

	if {$type eq "extract"} {
		bind_extraction_list 0 1
		bind_exception_list
	} elseif {$type eq "exception"} {
		bind_extraction_list
		bind_exception_list 0 1
	}

	asPlayFile -nocache stralfors/stralfors.html
}



# replace_card
# Sets the customer's Stralfors flag to 'Y' and their letter code to 'R'
#
proc ADMIN::STRALFORS::replace_card args {
	global DB

	ob_log::write INFO {ADMIN::STRALFORS::replace_card}

	set cust_id [reqGetArg CustId]

	set stmt [inf_prep_sql $DB {
		update
			tCustStralfor
		set
			letter = 'R',
			exported = 'N',
			export_date = null
		where
			cust_id = ?
	}]
	set rs [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	OB_prefs::set_cust_flag $cust_id [OT_CfgGet STRALFORS_FLAG_NAME "Stralfors"] "Y"

	db_close $rs
}



# replace_welcome_pack
# Sets the customer's Stralfors code to the relevant New Welcome Pack code
# and sets their Stralfors flag to 'Y'
proc ADMIN::STRALFORS::replace_welcome_pack args {
	global DB

	ob_log::write INFO {ADMIN::STRALFORS::replace_welcome_pack}

	set cust_id [reqGetArg CustId]

	# Set the Stralfors code
	set_stralfors_code $cust_id

	set stmt [inf_prep_sql $DB {
		update
			tCustStralfor
		set
			exported = 'N',
			export_date = null
		where
			cust_id = ?
	}]
	set rs [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	OB_prefs::set_cust_flag $cust_id [OT_CfgGet STRALFORS_FLAG_NAME "Stralfors"] "Y"

	db_close $rs
}



# cancel_welcome_pack
# Cancels the welcome pack by setting the first digit to 0
proc ADMIN::STRALFORS::cancel_welcome_pack args {
	global DB

	ob_log::write INFO {ADMIN::STRALFORS::cancel_welcome_pack}

	set cust_id [reqGetArg CustId]

	set stmt [inf_prep_sql $DB {
		update
			tCustStralfor
		set
			print_code = '0'
		where
			cust_id = ?
	}]
	set rs [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	OB_prefs::set_cust_flag $cust_id [OT_CfgGet STRALFORS_FLAG_NAME "Stralfors"] "Y"

	db_close $rs
}



# add_flags
# Add a Stralfors flag to a customer account
proc ADMIN::STRALFORS::add_flags args {
	global DB

	ob_log::write INFO {ADMIN::STRALFORS::add_flags}

	set cust_id [reqGetArg CustId]
	set stralfors_flag  [OT_CfgGet STRALFORS_FLAG_NAME "Stralfors"]
	
	# This will only add the stralfors flag if the account meets the normal
	# flag criteria, must check for added flag
	tb_register::tb_stralfor_code $cust_id 1

	set stmt [inf_prep_sql $DB {
		select
			1
		from
			tCustomerFlag f
		where
			f.cust_id = ?
			and flag_name = ?
	}]

	set res [inf_exec_stmt $stmt $cust_id $stralfors_flag]
	inf_close_stmt $stmt

	if {[db_get_nrows $res] != 1} {
		OB_prefs::set_cust_flag $cust_id $stralfors_flag  "Y"
	}

	db_close $res

	ADMIN::CUST::go_cust
}


# save_flags
# Wrapper procedure for update_flags - calls update to insert as opposed to
# updating flags
proc ADMIN::STRALFORS::save_flags args {
	update_flags 0
}



# update_flags
#
proc ADMIN::STRALFORS::update_flags {{update 1}} {
	global DB

	set stral_id [reqGetArg stralfor_id]
	set print_code [reqGetArg print_code]
	set account_type [reqGetArg account_type]
	set letter  [reqGetArg letter]
	set tel_no [reqGetArg tel_no]
	set bus_cond [reqGetArg post]
	set cust_id [reqGetArg CustId]

	if {$update} {
		set stmt [inf_prep_sql $DB {
			update
				tCustStralfor
			set
				print_code   = ?,
				account_type = ?,
				letter       = ?,
				tel_no       = ?,
				bus_cond      = ?
			where
				stralfor_id = ?
		}]
		set rs [inf_exec_stmt $stmt $print_code $account_type $letter $tel_no \
			$bus_cond $stral_id]
	} else {
		set stmt [inf_prep_sql $DB {
			insert into
				tCustStralfor
					(cust_id, print_code, account_type, \
						letter, tel_no, bus_cond)
				values
					(?,?,?,?,?,?)
		}]
		set rs [inf_exec_stmt $stmt $cust_id $print_code $account_type \
			$letter $tel_no $bus_cond]
	}
	inf_close_stmt $stmt
	ADMIN::CUST::go_cust
}



# back_action
# returns to customer information page 
proc ADMIN::STRALFORS::back_action args {
	ADMIN::CUST::go_cust
}



# edit_code
# plays the edit stralfors code page for a customer
#
proc ADMIN::STRALFORS::edit_code args {
	global DB

	set stral_id [reqGetArg Stralfor_Id]
	
	tpBindString stralfor_id $stral_id
	tpBindString Cust_Id [reqGetArg CustId]
	 
	set stmtCust [inf_prep_sql $DB {
		select
			s.print_code,
			s.account_type,
			s.letter,
			s.tel_no,
			s.bus_cond
		from
			tCustStralfor s
		where
			s.stralfor_id = ?
	}]

	set res [inf_exec_stmt $stmtCust $stral_id]
	
	inf_close_stmt $stmtCust
	
	if {[db_get_nrows $res] == 1} {
		tpSetVar update 1
		tpBindString print_code   [db_get_col $res 0 print_code]
		tpBindString account_type [db_get_col $res 0 account_type]
		tpBindString letter       [db_get_col $res 0 letter]
		tpBindString tel_no       [db_get_col $res 0 tel_no]
		tpBindString bus_cond     [db_get_col $res 0 bus_cond]
	} else {
		tpSetVar update 0
	}
	db_close $res
	loop_codes stralfors/edit.html
}



# loop_codes
# loops through the different code types for displaying the codes and their
# descriptions
proc ADMIN::STRALFORS::loop_codes {play_file} {
	global DB

	set stmtPrint [inf_prep_sql $DB {
		select
			s.code,
			s.description
		from
			tStralfor s
		where
			s.type = 'Print Code'
	}]

	set res1 [inf_exec_stmt $stmtPrint]
	inf_close_stmt $stmtPrint

	tpSetVar NumPrint [db_get_nrows $res1]
	tpBindTcl p_code sb_res_data $res1 p_print_idx code
	tpBindTcl p_description sb_res_data $res1 p_print_idx description
	

	set stmtAccount [inf_prep_sql $DB {
		select
			s.code,
			s.description
		from
			tStralfor s
		where
			s.type = 'Account Types'
	}]

	set res2 [inf_exec_stmt $stmtAccount]
	inf_close_stmt $stmtAccount

	tpSetVar NumAccount [db_get_nrows $res2]
	tpBindTcl account_code sb_res_data $res2 account_idx code
	tpBindTcl account_description sb_res_data $res2 account_idx description

	set stmtLetter [inf_prep_sql $DB {
		select
			s.code,
			s.description
		from
			tStralfor s
		where
			s.type = 'Letter'
	}]

	set res3 [inf_exec_stmt $stmtLetter]
	inf_close_stmt $stmtLetter

	tpSetVar  NumLetter [db_get_nrows $res3]
	tpBindTcl letter_code sb_res_data $res3 letter_idx code
	tpBindTcl letter_description sb_res_data $res3 letter_idx description

	set stmtTel [inf_prep_sql $DB {
		select
			s.code,
			s.description
		from
			tStralfor s
		where
			s.type = 'Telephone Number'
	}]

	set res4 [inf_exec_stmt $stmtTel]
	inf_close_stmt $stmtTel

	tpSetVar NumTel [db_get_nrows $res4]
	tpBindTcl tel_code sb_res_data $res4 tel_idx code
	tpBindTcl tel_description sb_res_data $res4 tel_idx description

	set stmtBus [inf_prep_sql $DB {
		select
			s.code,
			s.description
		from
			tStralfor s
		where
			s.type = 'Business Condition'
	}]

	set res5 [inf_exec_stmt $stmtBus]
	inf_close_stmt $stmtBus
	
	tpSetVar NumBus [db_get_nrows $res5]
	tpBindTcl bus_code sb_res_data $res5 bus_idx code
	tpBindTcl bus_description sb_res_data $res5 bus_idx description

	asPlayFile -nocache $play_file
	db_close $res1
	db_close $res2
	db_close $res3
	db_close $res4
	db_close $res5
}



# Sets a new Stralfors code for a customer based on their account type, account
# group and age verification flag
proc ADMIN::STRALFORS::set_stralfors_code cust_id {

	global DB

	# Get the account type and account group
	set stmt [inf_prep_sql $DB {
		select
			r.code
		from
			tCustomerReg r
		where
			cust_id = ?
	}]

	set rs [inf_exec_stmt $stmt $cust_id]

	if {[db_get_nrows $rs] > 0} {
		set group_code [db_get_col $rs 0 code]
	} else {
		inf_close_stmt $stmt
		return
	}

	inf_close_stmt $stmt

	# Get the age verification status
	set av_status 0
	if {[OT_CfgGet FUNC_OVS 0]} {
		set av_status [verification_check::get_ovs_status $cust_id "AGE"]
	}
	switch -- $av_status {
		A {
			set age_vrf 1
		}
		default {
			set age_vrf 0
		}
	}

	if {[lsearch {"G" "P" "T3"} $group_code] != -1} {
		set check_group 1
	} else {
		set check_group 0
	}

	# Get the code for this customer
	set stmt [inf_prep_sql $DB {
		select
			s.print_code,
			s.account_type,
			s.letter,
			s.tel_no,
			s.business_cond
		from
			tStralforCode s,
			tCustomer c,
			tAcct a,
			tCustomerReg r
		where
			c.cust_id = ?
			and c.cust_id = a.cust_id
			and s.acct_type = a.acct_type
			and (?=0 or s.cust_sort = r.code)
			and (a.acct_type = 'CDT' or s.age_verified = ?)
			and r.cust_id = c.cust_id
	}]

	set rs [inf_exec_stmt $stmt $cust_id $check_group $age_vrf]
	inf_close_stmt $stmt

	if {[db_get_nrows $rs] > 0} {
		set print_code      [db_get_col $rs 0 print_code]
		set account_type    [db_get_col $rs 0 account_type]
		set letter          [db_get_col $rs 0 letter]
		set tel_no          [db_get_col $rs 0 tel_no]
		set business_cond   [db_get_col $rs 0 business_cond]
	} else {
		# No Stralfors code returned
		return
	}
	
	# Insert the new code
	set stmt [inf_prep_sql $DB {
		update
			tCustStralfor
		set
			print_code   = ?,
			account_type = ?,
			letter       = ?,
			tel_no       = ?,
			bus_cond     = ?
		where
			cust_id = ?
	}]
	set rs [inf_exec_stmt $stmt $print_code $account_type $letter $tel_no \
		$business_cond $cust_id]

	inf_close_stmt $stmt
	db_close $rs
}



# stral_esc
# Escape pipe delimiters in a string. Used when creating CSV file.
#
proc ADMIN::STRALFORS::stral_esc str {

	if {[string match {|} $str]} {
		set str "\"$str\""
	}

	return $str
}
