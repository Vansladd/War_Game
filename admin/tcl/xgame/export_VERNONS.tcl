# ==============================================================
# $Id: export_VERNONS.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

array set sort_codes [list "VPOOLSM" 15 "VPOOLS11" 72 "VPOOLS10" 91 "LCLOVER3" 53 "LCLOVER5" 34]


proc populate_xgame_export_queries args {
    global xgaQry

    set xgaQry(create_export_file) {execute procedure 
		pCreateXGameExFile (
				      p_filename = ?,
				      p_sort     = ?,
				      p_type     = ?
				      )
    }

    set xgaQry(create_customers_export_file) {execute procedure 
    pCreateCustExport (
	p_filename = ?
    )
    }
    

    set xgaQry(get_export_files) {
	select xgame_ex_file_id,
	filename,
	cr_date,
	type
	from tXGameExFile
	order by xgame_ex_file_id desc
    }

    set xgaQry(create_cust_export_file) {
	execute procedure 
	  pCreateCustExport( p_filename = ? )
    }

    set xgaQry(get_custs_in_file) {
	select distinct
		a.acct_id,
		r.fname,
		r.lname,
		r.addr_street_1,
		r.addr_street_2,
		r.addr_street_3,
		r.addr_street_4,
		r.addr_city,
		r.addr_postcode,
		c.country_code,
		r.telephone,
		r.email,
		r.contact_ok,
		r.ptnr_contact_ok,
		r.hear_about,
		r.hear_about_txt,
		r.dob,
		a.ccy_code,
		r.mobile

	from    tCustomer c,
		tAcct a,
		tCustomerReg r

	where   c.cust_id = a.cust_id
	and     c.cust_id = r.cust_id
	and     c.cust_id in 
	    (select cust_id from txgameexcust where xgame_ex_file_id = ?)
    }
		


    set xgaQry(get_bets_from_file) {
	select b.xgame_bet_id, 
	s.xgame_sub_id, 
	s.cr_date,
	g.draw_at,
	comp_no,
	b.picks
	from tXGameExFile ef,
	tXGameExBet  eb,
	tXGameBet b,
	tXGameSub s,
	tXGame g,
	tAcct a
	
	where ef.xgame_ex_file_id = eb.xgame_ex_file_id
	and eb.xgame_bet_id = b.xgame_bet_id
	and b.xgame_sub_id = s.xgame_sub_id
	and b.xgame_id = g.xgame_id
	and s.acct_id = a.acct_id
	and ef.xgame_ex_file_id = ?
    }

    set xgaQry(get_subs_from_file) {
	select  s.cr_date,
		s.xgame_sub_id,
		a.acct_id,
		s.num_subs,
		s.picks,
		g.sort,
		s.source,
		nvl(s.aff_id,0) as aff_id,
		s.stake_per_bet

	from    tXGameExFile ef,
		tXGameExSub  es,
		tXGameSub s,
		tXGame g,
		tAcct a
	
	where   ef.xgame_ex_file_id = es.xgame_ex_file_id
	and     es.xgame_sub_id     = s.xgame_sub_id
	and     s.xgame_id          = g.xgame_id
	and     s.acct_id           = a.acct_id
	and     ef.xgame_ex_file_id = ?
    }

    set xgaQry(get_file_details) {
	select
	cr_date,
	filename,
	type
	from tXGameExFile
	where xgame_ex_file_id = ?
    }
}

proc export_file {{dest "I"} {xgame_ex_file_id ""}} {
    global xgaQry
    global sort_codes
    
    # Get file details
    if {$xgame_ex_file_id == "" && $dest == "I"} {
	set xgame_ex_file_id [reqGetArg xgame_ex_file_id]
    }
    
    if [catch {set rs [xg_exec_qry $xgaQry(get_file_details) $xgame_ex_file_id]} msg] {
	return [handle_err "get_file_details"\
		"error: $msg"]        
    }
    
    set cr_date  [db_get_col $rs 0 cr_date]
    set type     [db_get_col $rs 0 type]
    set filename [db_get_col $rs 0 filename]
    
    db_close $rs
    
    
    # Is it a customer data export?
    if {$type == "CUST"} {
	export_cust_file $dest
	return
    }
    
    set count_recs 0
    # What type of file are we exporting BET, SUB or ALL
    if {$type != ""} {
	set type    [string range $type 0 2]
    } else {
	set type    "BET"
    }
    
    if {$type == "BET"} {
	set rec_len 92
	#set rec_len 76
    } else {
	set rec_len 81
	#set rec_len 93
    }
    
    OT_LogWrite 20 "export_file: type=$type rec_len=$rec_len"
    
    ## Generate records
    set record ""
    
    if {$type == "BET" || $type == "ALL"} {
	if [catch {set rs [xg_exec_qry $xgaQry(get_bets_from_file) $xgame_ex_file_id]} msg] {
	    return [handle_err "get_bets_from_file"\
		    "error: $msg"]        
	}
	
	set nrows [db_get_nrows $rs]
	OT_LogWrite 20 "export_file: $type nrows=$nrows"
	
	for {set r 0} {$r < $nrows} {incr r} {
	    
	    set cr_date      [db_get_col $rs $r cr_date]
	    set xgame_bet_id [db_get_col $rs $r xgame_bet_id]
	    set xgame_sub_id [db_get_col $rs $r xgame_sub_id] 	    
	    set draw_at      [db_get_col $rs $r draw_at]
            set comp_no      [db_get_col $rs $r comp_no]
	    ## Numbers selected
	    set picks        [db_get_col $rs $r picks]
	    
	    ## Create record 

	    ## Bet_id
	    append record    [format {%010d} $xgame_bet_id]
	    
	    ## Sub id
	    append record    [format {%010d} $xgame_sub_id]
	    
	    ## Comp draw at date/time
	    set datetime ""
	    regexp {[0-9]{4,4}-[0-9]{2,2}-[0-9]{2,2} [0-9]{2,2}:[0-9]{2,2}} $draw_at datetime
	    append record $datetime	   

            ## Comp no
            append record    [format {%010d} $comp_no]	
	    
	    ## Bet date/time
	    set datetime ""
	    regexp {[0-9]{4,4}-[0-9]{2,2}-[0-9]{2,2} [0-9]{2,2}:[0-9]{2,2}} $cr_date datetime
	    append record $datetime

	    ## Picks
	    set selections ""
	    foreach p [split $picks "|"] {
		append selections [format {%02d} $p]
	    }
	    append record     [format {%030s} $selections]
	    
	    # Final line break
	    append record "\n"
	    
	    incr count_recs
	}
	
	db_close $rs
    }
    
    if {$type == "SUB" || $type == "ALL"} {
	if [catch {set rs [xg_exec_qry $xgaQry(get_subs_from_file) $xgame_ex_file_id]} msg] {
	    return [handle_err "get_subs_from_file"\
		    "error: $msg"]        
	}
	
	set nrows [db_get_nrows $rs]
	OT_LogWrite 20 "export_file: $type nrows=$nrows"
	
	for {set r 0} {$r < $nrows} {incr r} {
	    
	    
	    set cr_date       [db_get_col $rs $r cr_date]
	    set xgame_sub_id  [db_get_col $rs $r xgame_sub_id]
	    set acct_id       [db_get_col $rs $r acct_id]
	    set num_subs      [db_get_col $rs $r num_subs]
	    set picks         [db_get_col $rs $r picks]
	    set sort          [db_get_col $rs $r sort]
	    set source        [db_get_col $rs $r source]
	    set aff_id        [db_get_col $rs $r aff_id]
	    set stake_per_bet [db_get_col $rs $r stake_per_bet]
	    
	    
	    ## Subscription date/time
	    set datetime ""
	    regexp {[0-9]{4,4}-[0-9]{2,2}-[0-9]{2,2} [0-9]{2,2}:[0-9]{2,2}} $cr_date datetime
	    append record $datetime
	    
	    ## Sub id
	    append record     [format {%010d} $xgame_sub_id]
	    
	    ## Customer's account id
	    append record     [format {%010d} $acct_id]		
	    
	    ## Number of subs
	    append record     [format {%02d} $num_subs]
	    
	    ## Picks
	    set selections ""
	    foreach p [split $picks "|"] {
		append selections [format {%02d} $p]
	    }
	    append record     [format {%030s} $selections]
	    
	    ## Game type
	    append record     [format {%02d} $sort_codes($sort)]
	    
	    ## Source
	    append record     [format {%-s} $source]
	    
	    ## Affiliate id
	    append record     [format {%010d} $aff_id]

	    ## Stake per bet in user currency
	    #append record     [format {%012.2f} $stake_per_bet]
	    
	    
	    # Final line break
	    append record "\n"
	    
	    incr count_recs
	}
	
	db_close $rs
    }
    
    # Write header
    set header ""
    
    # File Creation Date/Time
    set datetime ""
    regexp {[0-9]{4,4}-[0-9]{2,2}-[0-9]{2,2} [0-9]{2,2}:[0-9]{2,2}} $cr_date datetime
    append header $datetime
    
    # Number of total recs
    append header [format {%010d} $count_recs]
    
    # Filler
    append header [format %0[expr $rec_len - 26]d 0]
    
    # Final line break
    append header "\n"
    
    
    # Output to Web Page by default or File
    if {$dest == "I"} {
	tpBufAddHdr "Pragma" "no-cache"
	tpBufAddHdr "Content-Type" "text/plain"
	
	tpBufWrite $header
	tpBufWrite $record
    } else {
	set exp_fdir   [OT_CfgGet EXP_FILE_DIR]
	set bckup_fdir [OT_CfgGet BCKUP_FILE_DIR]
	
	regsub -- DATA $filename HEAD h_filename
	if [catch {set fileid [open "$exp_fdir/$h_filename.tmp" "w"]} msg] {
	    return [handle_err "output file:" "Cannot open file for writing: $exp_fdir/$h_filename.tmp"]
	}
	
	puts -nonewline $fileid $header
	close $fileid
	puts stderr "**** Finished writing output file $h_filename.tmp *****"

	exec cp ${exp_fdir}/${h_filename}.tmp ${bckup_fdir}/$h_filename
	exec mv ${exp_fdir}/${h_filename}.tmp ${exp_fdir}/$h_filename
	puts stderr "**** Copied to $h_filename *****"
	
	if [catch {set fileid [open "$exp_fdir/$filename.tmp" "w"]} msg] {
	    return [handle_err "output file:" "Cannot open file for writing: $exp_fdir/$filename.tmp"]
	}
	
	puts -nonewline $fileid $record
	close $fileid
	puts stderr "**** Finished writing output file $filename.tmp *****"

	exec cp ${exp_fdir}/${filename}.tmp ${bckup_fdir}/$filename
	exec mv ${exp_fdir}/${filename}.tmp ${exp_fdir}/$filename
	puts stderr "**** Copied to $filename *****"	
    }
    
    return
}

proc create_customers_export_file {{dest "I"}} {
    global xgaQry
    
    if {$dest == "I"} {
	set filename [reqGetArg filename]
	set sort     [reqGetArg sort]
	set type     [reqGetArg type]
    } else {
	set filename [OT_CfgGet CUST_FILE_NAME "CUST"]
    }

    set cr_date [clock format [clock seconds] -format "%Y%m%d%H%M%S"]
    if {$filename != ""} {
	append filename ".$cr_date"
    } else {
	set    filename   $cr_date
    }

    OT_LogWrite 20 "create_customers_export_file: filename=$filename"

    if [catch {set rs [xg_exec_qry $xgaQry(create_customers_export_file)\
	    $filename]} msg] {
	return [handle_err "create_customers_export_file"\
		"error: $msg"]        
    }

    set xgame_ex_file_id [db_get_coln $rs 0 0]

    db_close $rs

    if {$dest == "I"} {
	X_play_file filecreated.html
    } else {

	#if [catch {set rs [xg_exec_qry $xgaQry(get_export_files)]} msg] {
	#	return [handle_err "get_export_files"\
	#	    "error: $msg"]        
	#} 
	
	#export_file "F" [db_get_col $rs 0 xgame_ex_file_id]
	export_cust_file "F" $xgame_ex_file_id
    }

}

proc export_cust_file {{dest "I"} {xgame_ex_file_id ""}} {
    global xgaQry DB

    # Get file details
    if {$xgame_ex_file_id == "" && $dest == "I"} {
	set xgame_ex_file_id [reqGetArg xgame_ex_file_id]
    }
    
    set count_recs 0
    
    set rec_len 402
    OT_LogWrite 20 "export_cust_file: rec_len=$rec_len"
    
    ## Generate records
    set record ""
    
    if [catch {set rs [xg_exec_qry $xgaQry(get_custs_in_file) $xgame_ex_file_id]} msg] {
	return [handle_err "get_custs_in_file" "error: $msg"]        
    }
    set cur_date   [clock format [clock seconds] -format "%Y%m%d%H%M%S"]
    set nrows [db_get_nrows $rs]
    OT_LogWrite 20 "export_cust_file: nrows=$nrows"
    
    for {set r 0} {$r < $nrows} {incr r} {
	
	set acct_id         [db_get_col $rs $r acct_id]
	set fname           [db_get_col $rs $r fname]
	set lname           [db_get_col $rs $r lname]
	set addr_street_1   [db_get_col $rs $r addr_street_1]
	set addr_street_2   [db_get_col $rs $r addr_street_2]
	set addr_street_3   [db_get_col $rs $r addr_street_3]
	set addr_street_4   [db_get_col $rs $r addr_street_4]
	set addr_city       [db_get_col $rs $r addr_city]
	set addr_postcode   [db_get_col $rs $r addr_postcode]
	set country_code    [db_get_col $rs $r country_code]
	set telephone       [db_get_col $rs $r telephone]
	set email           [db_get_col $rs $r email]
	set contact_ok      [db_get_col $rs $r contact_ok]
	set ptnr_contact_ok [db_get_col $rs $r ptnr_contact_ok]
	set hear_about      [db_get_col $rs $r hear_about]
	set hear_about_txt  [db_get_col $rs $r hear_about_txt]
	set dob             [db_get_col $rs $r dob]
	set ccy_code        [db_get_col $rs $r ccy_code]
	set mobile          [db_get_col $rs $r mobile]
	
	## Account id
	append record     [format {%010d} $acct_id]		
	
	## First Name
	append record     [format {%-30.30s} $fname]
	
	## Last Name
	append record     [format {%-30.30s} $lname]
	
	## Address Fields
	append record     [format {%-30.30s} $addr_street_1]
	append record     [format {%-30.30s} $addr_street_2]
	append record     [format {%-30.30s} $addr_street_3]
	append record     [format {%-30.30s} $addr_street_4]
	append record     [format {%-40.40s} $addr_city]
	append record     [format {%-20.20s} $addr_postcode]
	
	append record     [format {%-3.3s}   $country_code]
	
	## Telephone
	append record     [format {%-20.20s} $telephone]
	
	## Email addr
	append record     [format {%-60.60s} $email]
	
	## Contact etc
	append record     [format {%-1.1s}   $contact_ok]
	append record     [format {%-1.1s}   $ptnr_contact_ok]
	append record     [format {%-4.4s}   $hear_about]
	append record     [format {%-30.30s} $hear_about_txt]

	## Dob
	append record     [format {%-10.10s} $dob]

	## Currency code
	append record     [format {%-3.3s}   $ccy_code]

	## Mobile
	append record     [format {%-20.20s} $mobile]
	
	# Final line break
	append record "\n"
	
	incr count_recs
    }
    
    db_close $rs
    
    # Write header
    set header ""
    
    # File Creation Date/Time
    set datetime ""
    regexp {([0-9]{4,4})([0-9]{2,2})([0-9]{2,2})([0-9]{2,2})([0-9]{2,2})} $cur_date junk Year Mon Day h m
    set datetime "${Year}-${Mon}-${Day} ${h}:${m}"
    append header $datetime
    
    # Number of total recs
    append header [format {%010d} $count_recs]
    
    # Filler
    append header [format %0[expr $rec_len - 26]d 0]
    
    # Final line break
    append header "\n"
    
    
    # Output to Web Page by default or File
    if {$dest == "I"} {
	tpBufAddHdr "Pragma" "no-cache"
	tpBufAddHdr "Content-Type" "text/plain"
	
	tpBufWrite $header
	tpBufWrite $record
    } else {
	set exp_fdir   [OT_CfgGet EXP_FILE_DIR]
	set bckup_fdir [OT_CfgGet BCKUP_FILE_DIR]
	
	set h_fname    "CUSTHEAD.${cur_date}"
	set fname      "CUSTDATA.${cur_date}"
	
	if [catch {set fileid [open "$exp_fdir/${h_fname}.tmp" "w"]} msg] {
	    return [handle_err "output file:" "Cannot open file for writing: $exp_fdir/${h_fname}.tmp"]
	}
	puts -nonewline $fileid $header
	close $fileid
	puts stderr "**** Finished writing output file $h_fname.tmp *****"

	exec cp ${exp_fdir}/${h_fname}.tmp ${bckup_fdir}/$h_fname
	exec mv ${exp_fdir}/${h_fname}.tmp ${exp_fdir}/$h_fname
	puts stderr "**** Copied to $h_fname *****"
		
	if [catch {set fileid [open "$exp_fdir/${fname}.tmp" "w"]} msg] {
	    return [handle_err "output file:" "Cannot open file for writing: $exp_fdir/${fname}.tmp"]
	}
	puts -nonewline $fileid $record
	
	close $fileid
	puts stderr "**** Finished writing output file $fname.tmp *****"

	exec cp ${exp_fdir}/${fname}.tmp ${bckup_fdir}/$fname
	exec mv ${exp_fdir}/${fname}.tmp ${exp_fdir}/$fname
	puts stderr "**** Copied to $fname *****"
	
    }
    
}
