# ==============================================================
# $Id: ldt.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2001 Orbis Technology Ltd. All rights reserved.
# ==============================================================

#
# ----------------------------------------------------------------------------
# Procedures called from here do their own transaction management
# ----------------------------------------------------------------------------
#
namespace eval ADMIN::LDT {

asSetAct ADMIN::LDT::GoLocDeptTerm    [namespace code go_ldt_list]
asSetAct ADMIN::LDT::GoLoc            [namespace code go_loc]
asSetAct ADMIN::LDT::DoLoc            [namespace code do_loc]
asSetAct ADMIN::LDT::GoDept           [namespace code go_dept]
asSetAct ADMIN::LDT::DoDept           [namespace code do_dept]
asSetAct ADMIN::LDT::GoTerm           [namespace code go_term]
asSetAct ADMIN::LDT::DoTerm           [namespace code do_term]
asSetAct ADMIN::LDT::DoAddTermAcct    [namespace code do_addtermacct]
asSetAct ADMIN::LDT::DoLDTPerm        [namespace code do_ldt_perm]


if {[OT_CfgGet TERM_LANGS 0]} {
	# Setup SQL that is available for this namespace
	variable SQL

	set SQL(get_langs) {
		select
			a.lang
		from
			tAdminTermLang a
		where
			a.term_code = ?
	}

	set SQL(del_lang) {
		delete
			from tAdminTermLang
		where
			term_code = ?
		and lang = ?
	}

	set SQL(ins_lang) {
		insert into
		tAdminTermLang (term_code,lang)
		values(?,?)
	}

	set SQL(del_lang_all) {
		delete
			from tAdminTermLang
		where
			term_code = ?
	}

	set SQL(get_lang_all) {
		select
			lang
		from
			tlang
	}
}




#
# ----------------------------------------------------------------------------
# 3 procedures to set binds for location, department and terminal lists
# ----------------------------------------------------------------------------
#
proc bind_locs {} {

	global DB LOC

	set sql_l [subst {
		select
			loc_code,
			loc_name
		from
			tAdminLoc
		order by
			loc_code
	}]

	set stmt   [inf_prep_sql $DB $sql_l]
	set res_l  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumLocs [set nrows [db_get_nrows $res_l]]

	for {set r 0} {$r < $nrows} {incr r} {
		set LOC($r,code) [db_get_col $res_l $r loc_code]
		set LOC($r,name) [db_get_col $res_l $r loc_name]
	}

	db_close $res_l

	tpBindVar LocCode    LOC code loc_idx
	tpBindVar LocName    LOC name loc_idx

}


proc bind_depts {} {

	global DB DEPT

	set sql_d [subst {
		select
			dept_code,
			dept_name,
			NVL(ev_db_url, 'DEFAULT') ev_db_url
		from
			tAdminDept
		order by
			dept_code
	}]

	set stmt   [inf_prep_sql $DB $sql_d]
	set res_d  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumDepts [set nrows [db_get_nrows $res_d]]

	for {set r 0} {$r < $nrows} {incr r} {
		set DEPT($r,code) [db_get_col $res_d $r dept_code]
		set DEPT($r,name) [db_get_col $res_d $r dept_name]
		set DEPT($r,url)  [db_get_col $res_d $r ev_db_url]
	}

	db_close $res_d

	tpBindVar DeptCode    DEPT code dept_idx
	tpBindVar DeptName    DEPT name dept_idx
	tpBindVar DeptEvDbUrl DEPT url dept_idx
}

proc bind_channels {} {

	global DB CHANNELS

	array unset CHANNELS

	set sql [subst {
		select
			c.channel_id,
			c.desc
		from
			tChannel     c,
			tChanGrpLink l
		where
			c.channel_id  = l.channel_id
		and l.channel_grp in ('TEL', 'ANON', 'HOSP')
		order by
			c.desc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]
	set colnames [db_get_colnames $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		foreach n $colnames {
			set CHANNELS($r,$n) [db_get_col $rs $r $n]
		}
	}

	db_close $rs

	foreach {n site} {channel_id C_ChannelId desc C_Desc} {
		tpBindVar $site CHANNELS $n channel_idx
	}

	tpSetVar NumChannels $nrows
}


proc bind_terms {} {

	global DB TERM

	set sql_t [subst {
		select
			term_code,
			dept_code,
			loc_code,
			term_name,
			status,
			ident,
			telephone,
			channels
		from
			tAdminTerm
		order by
			loc_code,
			dept_code,
			term_code
	}]

	set stmt   [inf_prep_sql $DB $sql_t]
	set res_t  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumTerms [set nrows [db_get_nrows $res_t]]

	for {set r 0} {$r < $nrows} {incr r} {

		set TERM($r,TermCode)     [db_get_col $res_t $r term_code]
		set TERM($r,TermDept)     [db_get_col $res_t $r dept_code]
		set TERM($r,TermLoc)      [db_get_col $res_t $r loc_code]
		set TERM($r,TermName)     [db_get_col $res_t $r term_name]
		set TERM($r,TermStatus)   [db_get_col $res_t $r status]
		set TERM($r,TermIdent)    [db_get_col $res_t $r ident]
		set TERM($r,TermTel)      [db_get_col $res_t $r telephone]
		set TERM($r,TermChannels) [db_get_col $res_t $r channels]
	}

	db_close $res_t

	tpBindVar TermCode      TERM TermCode      term_idx
	tpBindVar TermDept      TERM TermDept      term_idx
	tpBindVar TermLoc       TERM TermLoc       term_idx
	tpBindVar TermName      TERM TermName      term_idx
	tpBindVar TermStatus    TERM TermStatus    term_idx
	tpBindVar TermIdent     TERM TermIdent     term_idx
	tpBindVar TermTel       TERM TermTel       term_idx
	tpBindVar TermChannels  TERM TermChannels  term_idx
}


#
# ----------------------------------------------------------------------------
# produce "generic" permission screen for each of loc/dept/term
# ----------------------------------------------------------------------------
#
proc go_perms {sort code} {

	global DB LDTP

	switch -- $sort {
		Term {
			set perm_tab tAdminTermOp
			set perm_col term_code
			tpBindString TermCode $code
		}
		Dept {
			set perm_tab tAdminDeptOp
			set perm_col dept_code
			tpBindString DeptCode $code
		}
		Loc {
			set perm_tab tAdminLocOp
			set perm_col loc_code
			tpBindString LocCode $code
		}
	}

	tpSetVar     PermOp $sort
	tpBindString PermOp $sort

	set sql [subst {
		select
			o.action,
			o.desc,
			t.type,
			t.desc type_desc,
			case
				when r.$perm_col is not null then 'CHECKED' else ''
			end status,
			NVL(t.disporder,0) t_disporder,
			NVL(o.disporder,0) o_disporder
		from
			tAdminOp o,
			tAdminOpType t,
			outer $perm_tab r
		where
			r.$perm_col = ? and
			o.action = r.action and
			o.type = t.type and
			NVL(o.disporder,0) >= 0
		order by
			t_disporder,
			t.type,
			o_disporder
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $code]
	inf_close_stmt $stmt

	set n_rows  [db_get_nrows $res]

	set n_perms -1
	set n_grps  -1

	set c_grp ""

	for {set r 0} {$r < $n_rows} {incr r} {

		if {[set grp [db_get_col $res $r type]] != $c_grp} {

			incr n_grps
			set c_grp $grp
			set n_perms 0
			set LDTP($n_grps,op_grp_name) [db_get_col $res $r type_desc]
		}

		set LDTP($n_grps,$n_perms,op)          [db_get_col $res $r action]
		set LDTP($n_grps,$n_perms,op_desc)     [db_get_col $res $r desc]
		set LDTP($n_grps,$n_perms,op_selected) [db_get_col $res $r status]

		set LDTP($n_grps,n_perms) [incr n_perms]
	}

	if {$n_rows} {
		incr n_grps
	}

	db_close $res

	tpSetVar NumPermGrps     $n_grps

	tpBindVar AdminOpGrp  LDTP op_grp_name grp_idx
	tpBindVar AdminOp     LDTP op          grp_idx perm_idx
	tpBindVar AdminOpDesc LDTP op_desc     grp_idx perm_idx
	tpBindVar OpSelected  LDTP op_selected grp_idx perm_idx

	asPlayFile -nocache ldt_perm.html

	catch {unset LDTP}
}


#
# ----------------------------------------------------------------------------
# Go to list of locations, departments and terminals
# ----------------------------------------------------------------------------
#
proc go_ldt_list args {

	global DB LOC DEPT TERM

	bind_locs
	bind_depts

	asPlayFile -nocache ldt.html

	catch {unset LOC}
	catch {unset DEPT}
	catch {unset TERM}
}


#
# ----------------------------------------------------------------------------
# Go to location add/update
# ----------------------------------------------------------------------------
#
proc go_loc args {

	global DB

	set loc_code [reqGetArg LocCode]

	foreach {n v} $args {
		set $n $v
	}

	tpBindString LocCode $loc_code

	if {$loc_code == ""} {

		tpSetVar opAdd 1

	} else {

		tpSetVar opAdd 0

		#
		# Get location information
		#
		set sql [subst {
			select
				loc_code,
				loc_name
			from
				tAdminLoc
			where
				loc_code = ?
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $loc_code]
		inf_close_stmt $stmt

		tpBindString LocCode      [db_get_col $res 0 loc_code]
		tpBindString LocName      [db_get_col $res 0 loc_name]

		db_close $res
	}

	asPlayFile -nocache location.html
}

proc do_loc args {

	global DB

	set act [reqGetArg SubmitName]

	if {$act == "LocAdd"} {

		set sql [subst {
			insert into tAdminLoc (
				loc_code,
				loc_name
			) values (
				?, ?
			)
		}]

		set stmt [inf_prep_sql $DB $sql]

		set c [catch {
			set res [inf_exec_stmt $stmt\
						 [reqGetArg LocCode]\
						 [reqGetArg LocName]]
			db_close $res
		}]

		inf_close_stmt $stmt

		if {$c} {
			error "failed to insert new location"
			return
		}

	} elseif {$act == "LocMod"} {

		set sql [subst {
			update tAdminLoc set
				loc_name = ?
			where
				loc_code = ?
		}]

		set stmt [inf_prep_sql $DB $sql]

		set c [catch {
			set res [inf_exec_stmt $stmt\
				[reqGetArg LocName]\
				[reqGetArg LocCode]]
			db_close $res
		}]

		inf_close_stmt $stmt

		if {$c} {
			error "failed to update location"
			return
		}

	} elseif {$act == "LocDel"} {

		set sql [subst {
			delete from tAdminLoc where loc_code = ?
		}]

		set stmt [inf_prep_sql $DB $sql]

		set c [catch {
			set res [inf_exec_stmt $stmt [reqGetArg LocCode]]
			db_close $res
		}]

		inf_close_stmt $stmt

		if {$c} {
			error "failed to delete location"
			return
		}

	} elseif {$act == "LocPerm"} {

		go_perms Loc [reqGetArg LocCode]
		return

	} elseif {$act == "Back"} {

	} else {
		error "unexpected SubmitName: $act"
	}

	go_ldt_list
}


#
# ----------------------------------------------------------------------------
# Go to department add/update
# ----------------------------------------------------------------------------
#
proc go_dept args {

	global DB

	set dept_code [reqGetArg DeptCode]

	foreach {n v} $args {
		set $n $v
	}

	tpBindString DeptCode $dept_code

	if {$dept_code == ""} {

		tpSetVar opAdd 1

	} else {

		tpSetVar opAdd 0

		#
		# Get location information
		#
		set sql [subst {
			select
				dept_code,
				dept_name,
				ev_db_url
			from
				tAdminDept
			where
				dept_code = ?
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $dept_code]
		inf_close_stmt $stmt

		tpBindString DeptCode      [db_get_col $res 0 dept_code]
		tpBindString DeptName      [db_get_col $res 0 dept_name]
		tpBindString DeptEvDbUrl   [db_get_col $res 0 ev_db_url]

		db_close $res
	}

	asPlayFile -nocache department.html
}

proc do_dept args {

	global DB

	set act [reqGetArg SubmitName]

	if {$act == "DeptAdd"} {

		set sql [subst {
			insert into tAdminDept (
				dept_code,
				dept_name,
				ev_db_url
			) values (
				?, ?, ?
			)
		}]

		set stmt [inf_prep_sql $DB $sql]

		set c [catch {
			set res [inf_exec_stmt $stmt\
				[reqGetArg DeptCode]\
				[reqGetArg DeptName]\
				[reqGetArg DeptEvDbUrl]]
			db_close $res
		}]

		inf_close_stmt $stmt

		if {$c} {
			error "failed to insert new department"
			return
		}

	} elseif {$act == "DeptMod"} {

		set sql [subst {
			update tAdminDept set
				dept_name = ?,
				ev_db_url = ?
			where
				dept_code = ?
		}]

		set stmt [inf_prep_sql $DB $sql]

		set c [catch {
			set res [inf_exec_stmt $stmt\
				[reqGetArg DeptName]\
				[reqGetArg DeptEvDbUrl]\
				[reqGetArg DeptCode]]
			db_close $res
		}]

		inf_close_stmt $stmt

		if {$c} {
			error "failed to update department"
			return
		}

	} elseif {$act == "DeptDel"} {

		set sql [subst {
			delete from tAdminDept where dept_code = ?
		}]

		set stmt [inf_prep_sql $DB $sql]

		set c [catch {
			set res [inf_exec_stmt $stmt [reqGetArg DeptCode]]
			db_close $res
		}]

		inf_close_stmt $stmt

		if {$c} {
			error "failed to delete department"
			return
		}

	} elseif {$act == "DeptPerm"} {

		go_perms Dept [reqGetArg DeptCode]
		return

	} elseif {$act == "Back"} {

	} else {
		error "unexpected SubmitName: $act"
	}

	go_ldt_list
}


#
# ----------------------------------------------------------------------------
# Go to terminal add/update
# ----------------------------------------------------------------------------
#
proc go_term args {

	global DB LOC DEPT RESULTSARRAY RESULTSARRAYCCY
	variable SQL

	set term_code [reqGetArg TermCode]
	set act [reqGetArg SubmitName]

	foreach {n v} $args {
		set $n $v
	}

	if {$act == "TermShow"} {
		bind_terms
		asPlayFile -nocache terminal_list.html
		return
	}

	tpBindString TermCode $term_code

	bind_locs
	bind_depts
	bind_channels

	if {$term_code == ""} {

		tpSetVar opAdd 1

	} else {

		tpSetVar opAdd 0

		#
		# Get terminal information
		#
		set sql [subst {
			select
				t.term_code,
				t.dept_code,
				t.loc_code,
				t.term_name,
				t.status,
				t.ident,
				t.telephone,
				t.channels,
				t.type,
				t.printer_type,
				t.printer_port,
				t.printer_baud_rate,
				t.card_reader_type,
				t.card_reader_port,
				t.display_type,
				t.default_ccy,
				t.default_lang,
				t.payout_perm,
				t.payout_limit

			from
				tAdminTerm t
			where
				t.term_code = ?
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $term_code]
		inf_close_stmt $stmt

		tpBindString TermDept      [db_get_col $res 0 dept_code]
		tpBindString TermLoc       [db_get_col $res 0 loc_code]
		tpBindString TermName      [db_get_col $res 0 term_name]
		tpBindString TermStatus    [db_get_col $res 0 status]
		tpBindString TermIdent     [db_get_col $res 0 ident]
		tpBindString TermTel       [db_get_col $res 0 telephone]
		tpBindString TermChannels  [db_get_col $res 0 channels]

		tpBindString PrinterType     [db_get_col $res 0 printer_type]
		tpBindString PrinterPort     [db_get_col $res 0 printer_port]
		tpBindString PrinterBaudRate [db_get_col $res 0 printer_baud_rate]
		tpBindString CardReaderType  [db_get_col $res 0 card_reader_type]
		tpBindString CardReaderPort  [db_get_col $res 0 card_reader_port]
		tpBindString DisplayType     [db_get_col $res 0 display_type]
		tpBindString DefaultCurrency [db_get_col $res 0 default_ccy]
		tpBindString DefaultLanguage [db_get_col $res 0 default_lang]
		tpBindString PayoutPerm      [db_get_col $res 0 payout_perm]
		tpBindString PayoutLimit     [db_get_col $res 0 payout_limit]

		set          termType        [db_get_col $res 0 type]
		tpBindString TermType        $termType
		tpSetVar     TermType        $termType


		#
		# Get terminal accounts
		#
		set acc_sql [subst {
			select
				a.ccy_code,
			    a.cust_id,
			    a.acct_type,
			    c.username
			from
				tTermAcct ta,
				tAcct     a,
			    tCustomer c
			where
				ta.acct_id   = a.acct_id
			and a.cust_id    = c.cust_id
			and a.status     = 'A'
			and c.type       = 'H'
			and ta.term_code = ?

			order by 1
		}]

		set acc_stmt [inf_prep_sql $DB $acc_sql]
		set acc_res  [inf_exec_stmt $acc_stmt $term_code]
		inf_close_stmt $acc_stmt

		# Retrieve the number of rows and columns
		set nrows_acc [db_get_nrows $acc_res]
		# Initialise an array with the result set values


		set idx 0
		set prev_ccy_code ""
		for {set i 0} {$i < $nrows_acc} {incr i} {
			set acct_type [db_get_col $acc_res $i acct_type]
			set ccy_code  [db_get_col $acc_res $i ccy_code]

			if {$ccy_code != $prev_ccy_code} {
				if {$ccy_code != ""} {
					incr idx
				}
				set prev_ccy_code $ccy_code
			}

			switch -- $acct_type {
				{PUB} {
					set RESULTSARRAY($idx,ccy_code)	    [db_get_col $acc_res $i ccy_code]
					set RESULTSARRAY($idx,cust_id_pub)  [db_get_col $acc_res $i cust_id]
					set RESULTSARRAY($idx,username_pub) [db_get_col $acc_res $i username]
				}
				{PRV} {
					set RESULTSARRAY($idx,username_prv) [db_get_col $acc_res $i username]
					set RESULTSARRAY($idx,cust_id_prv)  [db_get_col $acc_res $i cust_id]
				}
				default {
					error "invalid account type $acct_type"
				}

			}
		}

		# Remember1the length of the array
		if {$prev_ccy_code == ""} {
			tpSetVar NumAccounts 0
		} else {
			tpSetVar NumAccounts [incr idx]
		}

		tpBindVar CCYName      RESULTSARRAY      ccy_code      a_idx
		tpBindVar UserNamePub  RESULTSARRAY      username_pub  a_idx
		tpBindVar UserNamePrv  RESULTSARRAY      username_prv  a_idx
		tpBindVar CustIdPub    RESULTSARRAY      cust_id_pub   a_idx
		tpBindVar CustIdPrv    RESULTSARRAY      cust_id_prv   a_idx

		#
		# Get possible currencies for registering new terminal account
		#
		#Only check public accounts currencies to get rid of unnecessary duplicate currencies in query
		set ccy_sql [subst {
			select
				c.ccy_code
			from
				tCCy c
			where
				c.status = 'A'
			and	not exists (
				select
					a.ccy_code
				from
					tTermAcct ta,
					tAcct a
				where
					ta.acct_id   = a.acct_id
				and	a.acct_type  = 'PUB'
				and	a.ccy_code   = c.ccy_code
				and	ta.term_code = ?
			)
		}]

		set ccy_stmt [inf_prep_sql $DB $ccy_sql]
		set ccy_res  [inf_exec_stmt $ccy_stmt $term_code]
		inf_close_stmt $ccy_stmt

		# Retrieve the number of rows and columns
		set nrows_ccy [db_get_nrows $ccy_res]

		# Initialise an array with the result set values
		for {set i 0} {$i < $nrows_ccy} {incr i} {
			set RESULTSARRAYCCY($i,ccy_code) [db_get_col $ccy_res $i ccy_code]
		}

		# Remember the length of the array
		tpSetVar NumCCy $nrows_ccy

		tpBindVar CCYCode RESULTSARRAYCCY ccy_code ccy_idx

		db_close $res
	}

	if {[OT_CfgGet TERM_LANGS 0]} {
		if {$term_code == ""} {
			# Show a list of languages that can be selected for a terminal
			set lang_stmt [inf_prep_sql $DB $SQL(get_lang_all)]
			set lang_res  [inf_exec_stmt $lang_stmt]
		} else {
			# Get the languages currently selected for terminal
			set lang_stmt [inf_prep_sql $DB $SQL(get_langs)]
			set lang_res  [inf_exec_stmt $lang_stmt $term_code]
		}

		inf_close_stmt $lang_stmt

		# Retrieve the number of rows
		set nrows_lang [db_get_nrows $lang_res]

		set lang_list ""
		for {set i 0} {$i < $nrows_lang} {incr i} {
			if {$lang_list == ""} {
				set lang_list [db_get_col $lang_res $i lang]
			} else {
				set lang_list "$lang_list,[db_get_col $lang_res $i lang]"
			}
		}

		if {$term_code == ""} {
			make_language_binds $lang_list - 0 ""
		} else {
			make_language_binds $lang_list -
		}
	}



	asPlayFile -nocache terminal.html

	catch {unset RESULTSARRAYCCY}
	catch {unset RESULTSARRAY}
	catch {unset LOC}
	catch {unset DEPT}
}


proc do_addtermacct {{term_code ""} {ccy ""} {trans Y} {go_term 1}} {
	global DB
	set err 0

	ob::log::write INFO {TERM_ACCT: Adding $ccy for $term_code}

	if {$term_code == ""} {set term_code [reqGetArg term_code]}
	if {$ccy == ""}       {set ccy       [reqGetArg ccy_code]}

	ob::log::write INFO {TERM_ACCT: Adding $ccy for $term_code}

	set sql [subst {
		execute procedure pRegAnonTerm(
			p_term_code     = ?,
			p_ccy_code      = ?,
			p_transactional = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {inf_exec_stmt $stmt $term_code $ccy $trans} msg]} {
		err_bind "Registering new terminal failed."
	}

	inf_close_stmt $stmt
	if {$go_term} {go_term term_code $term_code}
	return $err
}

proc do_term args {

	global DB TP

	set act [reqGetArg SubmitName]

	set term_code [reqGetArg TermCode]

	tpBindString TermCode $term_code

	if {$act == "TermAdd"} {

		set sql_i [subst {
			insert into tAdminTerm (
				term_code,
				dept_code,
				loc_code,
				term_name,
				status,
				ident,
				telephone,
				channels,
				type,
				printer_type,
				printer_port,
				printer_baud_rate,
				card_reader_type,
				card_reader_port,
				display_type,
				default_ccy,
				default_lang,
				payout_perm,
				payout_limit
			) values (
				?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
			)
		}]

		set sql_p [subst {
			insert into tAdminTermOp (
				term_code,
				action
			) select
				'$term_code',
				action
			from
				tAdminDeptOp
			where
				dept_code = '[reqGetArg TermDept]'
		}]

		set stmt_i [inf_prep_sql $DB $sql_i]
		set stmt_p [inf_prep_sql $DB $sql_p]

		inf_begin_tran $DB

		set c [catch {

			set res [inf_exec_stmt $stmt_i\
				$term_code\
				[reqGetArg TermDept]\
				[reqGetArg TermLoc]\
				[reqGetArg TermName]\
				[reqGetArg TermStatus]\
				[reqGetArg TermIdent]\
				[reqGetArg TermTel]\
				[reqGetArg TermChannels]\
				[reqGetArg TermType]\
				[reqGetArg PrinterType]\
				[reqGetArg PrinterPort]\
				[reqGetArg PrinterBaudRate]\
				[reqGetArg CardReaderType]\
				[reqGetArg CardReaderPort]\
				[reqGetArg DisplayType]\
				[reqGetArg DefaultCurrency]\
				[reqGetArg DefaultLanguage]\
				[reqGetArg PayoutPerm]\
				[reqGetArg PayoutLimit]\
				]

			db_close $res

			set res [inf_exec_stmt $stmt_p]

			db_close $res
		}]

		inf_close_stmt $stmt_i
		inf_close_stmt $stmt_p

		if {$c} {
			inf_rollback_tran $DB
			error "failed to insert new terminal"
			return
		}

		inf_commit_tran $DB

	} elseif {$act == "TermMod"} {

		set sql [subst {
			update tAdminTerm set
				dept_code         = ?,
				loc_code          = ?,
				term_name         = ?,
				status            = ?,
				ident             = ?,
				telephone         = ?,
				channels          = ?,
				type              = ?,
				printer_type      = ?,
				printer_port      = ?,
				printer_baud_rate = ?,
				card_reader_type  = ?,
				card_reader_port  = ?,
				display_type      = ?,
				default_ccy       = ?,
				default_lang      = ?,
				payout_perm       = ?,
				payout_limit      = ?
			where
				term_code = ?
		}]

		set stmt [inf_prep_sql $DB $sql]

		set c [catch {
			set res [inf_exec_stmt $stmt\
				[reqGetArg TermDept]\
				[reqGetArg TermLoc]\
				[reqGetArg TermName]\
				[reqGetArg TermStatus]\
				[reqGetArg TermIdent]\
				[reqGetArg TermTel]\
				[reqGetArg TermChannels]\
				[reqGetArg TermType]\
				[reqGetArg PrinterType]\
				[reqGetArg PrinterPort]\
				[reqGetArg PrinterBaudRate]\
				[reqGetArg CardReaderType]\
				[reqGetArg CardReaderPort]\
				[reqGetArg DisplayType]\
				[reqGetArg DefaultCurrency]\
				[reqGetArg DefaultLanguage]\
				[reqGetArg PayoutPerm]\
				[reqGetArg PayoutLimit]\
				$term_code]
			db_close $res
		}]

		inf_close_stmt $stmt

		if {$c} {
			error "failed to update terminal"
			return
		}

	} elseif {$act == "TermDel"} {

		set sql [subst {
			delete from tAdminTerm where term_code = ?
		}]

		set stmt [inf_prep_sql $DB $sql]

		set c [catch {
			set res [inf_exec_stmt $stmt $term_code]
			db_close $res
		}]

		inf_close_stmt $stmt

		if {$c} {
			error "failed to delete terminal"
			return
		}

	} elseif {$act == "TermPerm"} {

		go_perms Term $term_code
		return

	} elseif {$act == "Back"} {

	} else {
		error "unexpected SubmitName: $act"
	}

	if {[OT_CfgGet TERM_LANGS 0]} {
		set update_langs [upd_langs $term_code]
		if {[lindex $update_langs 0]} {
			OT_LogWrite 1 "ldt:: Unable to update terminal langs."
			err_bind "Failed to insert terminal langs"
			go_term
			return
		}
	}

	go_ldt_list
}

# Procedure   : upd_langs
# Description : Build two lists, one will contain those langs that need to
#               be deleted, the other list will contain a list of those
#               langs that need to be inserted to the database
# ----------------------------------------------------------------------------
proc upd_langs {term_code} {
	global DB
	variable SQL

	set del_list  [list]

	# Get the languages that are ticked
	set lang_list [make_language_str]
	# Remove the commas between the language codes
	regsub -all {,} $lang_list " " lang_list

	# Get the list of langs in the DB for the terminal
	set lang_stmt  [inf_prep_sql $DB $SQL(get_langs)]
	set rs    [inf_exec_stmt $lang_stmt $term_code]
	inf_close_stmt $lang_stmt

	set n_langs  [db_get_nrows $rs]

	# List of langs that are in the db
	set db_langs ""

	for {set i 0} {$i < $n_langs} {incr i} {
		set db_lang      [db_get_col $rs $i lang]
		lappend db_langs $db_lang
	}

	set ins_lang_list ""

	foreach sel_lang $lang_list {
		if {[lsearch $db_langs $sel_lang] == -1} {
			lappend ins_lang_list $sel_lang
		}
	}

	set rem_lang_lst ""

	foreach lang $db_langs {
		if {[lsearch $lang_list $lang] == -1} {
			lappend rem_lang_lst $lang
		}
	}

	# delete all langs that are in the del_list
	set stmt [inf_prep_sql $DB $SQL(del_lang)]
	foreach d $rem_lang_lst {
		ob::log::write INFO {UPD_LANGS: Removing $d from $term_code}
		if [catch {set rs [inf_exec_stmt $stmt $term_code $d]} msg] {
			return [list 1 $msg]
		}
	}

	# Insert all langs that are left in the lang_list
	set stmt [inf_prep_sql $DB $SQL(ins_lang)]
	foreach v $ins_lang_list {
		ob::log::write INFO {UPD_LANGS: Adding $v from $term_code}
		if [catch {set rs [inf_exec_stmt $stmt $term_code $v]} msg] {
			return [list 1 $msg]
		}
	}
	return [list 0 OK]
}



proc do_ldt_perm args {

	global DB USERNAME

	if {![op_allowed AssignRights]} {
		error "You do not have permission to assign rights"
		go_term
		return
	}

	set sort [reqGetArg PermOp]

	switch -- $sort {
		Term {
			set perm_tab tAdminTermOp
			set perm_col term_code
			set code     [reqGetArg TermCode]
			set action   go_term
		}
		Dept {
			set perm_tab tAdminDeptOp
			set perm_col dept_code
			set code     [reqGetArg DeptCode]
			set action   go_dept
		}
		Loc {
			set perm_tab tAdminLocOp
			set perm_col loc_code
			set code     [reqGetArg LocCode]
			set action   go_loc
		}
	}

	set sql_d [subst {
		delete from $perm_tab where $perm_col = ?
	}]

	set sql_i [subst {
		insert into $perm_tab ($perm_col,action) values (?,?)
	}]

	set stmt_d [inf_prep_sql $DB $sql_d]
	set stmt_i [inf_prep_sql $DB $sql_i]


	inf_begin_tran $DB

	set r [catch {
		inf_exec_stmt $stmt_d $code

		for {set i 0} {$i < [reqGetNumVals]} {incr i} {
			set a [reqGetNthName $i]
			if {[string range $a 0 2] == "TP_"} {
				inf_exec_stmt $stmt_i $code [string range $a 3 end]
			}
		}
	} msg]

	if {$r} {
		inf_rollback_tran $DB
		err_bind $msg
	} else {
		inf_commit_tran $DB
	}

	inf_close_stmt $stmt_d
	inf_close_stmt $stmt_i

	$action
}

}
