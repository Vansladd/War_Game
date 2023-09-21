# ==============================================================
# $Id: call_search.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::CALL {

asSetAct ADMIN::CALL::GoCallQry     [namespace code go_call_query]
asSetAct ADMIN::CALL::do_call_query [namespace code do_call_query]
asSetAct ADMIN::CALL::do_call       [namespace code do_call]

#
# ----------------------------------------------------------------------------
# Generate customer selection criteria
# ----------------------------------------------------------------------------
#
proc go_call_query args {

    global DB BET_CHANNELS

    set sql {
        select
            cancel_code,
			cancel_desc,
			disporder,
			status
        from
            tCallCancel
		where
			status = 'A'
        order by
            disporder
    }

    set stmt [inf_prep_sql $DB $sql]
    set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

    tpSetVar NumCnlCodes [db_get_nrows $res]

    tpBindTcl cnl_code sb_res_data $res cnl_idx cancel_code
    tpBindTcl cnl_desc sb_res_data $res cnl_idx cancel_desc

    # get a list of all admins for the drop down list
    set sql2 {
        select
            username
        from
            tAdminUser
		order by
	        username
	}

    set stmt2 [inf_prep_sql $DB $sql2]
    set res2  [inf_exec_stmt $stmt2]

	inf_close_stmt $stmt2

    tpSetVar NumOperators [db_get_nrows $res2]
    tpBindTcl operator sb_res_data $res2 op_idx username

	# Get a list of all the channels
	set sql [subst {
		select channel_id, desc
		from tchannel
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res3  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set nrows [db_get_nrows $res3]

	for {set i 0} {$i < $nrows} {incr i} {
		set BET_CHANNELS($i,id) [db_get_col $res3 $i channel_id]
		set BET_CHANNELS($i,desc) [db_get_col $res3 $i desc]
	}

	set BET_CHANNELS(NumBetChannels) $nrows

	tpBindVar BetChannel        BET_CHANNELS id   bc_idx
	tpBindVar BetChannelDesc    BET_CHANNELS desc bc_idx


    asPlayFile -nocache call/call_search.html

    db_close $res
    db_close $res2
 	db_close $res3   
}


#
# ----------------------------------------------------------------------------
# Payment search
# ----------------------------------------------------------------------------
#
proc do_call_query args {

    global DB

	if {![op_allowed DoCallSearch]} {
		err_bind "You do not have permission to search customer calls"
		ADMIN::CALL::go_call_query
		return
	}


	set action [reqGetArg SubmitName]

	#
	# rebind most of the posted variables
	#
    foreach f {SR_username SR_upper_username SR_fname SR_lname SR_email \
               SR_acct_no_exact SR_acct_no SR_date_1 SR_date_2 \
               SR_date_range SR_operator SR_term_code \
               SR_bet_min SR_bet_max SR_grp_min SR_grp_max} {
		tpBindString $f [reqGetArg $f]
    }

    set where [list]

    #
    # Customer fields
    #
    set SR_username       [reqGetArg SR_username]
    set SR_upper_username [reqGetArg SR_upper_username]
    if {[string length $SR_username] > 0} {
        if {$SR_upper_username == "Y"} {
            lappend where "[upper_q c.username] like [upper_q '${SR_username}%']"
        } else {
            lappend where "c.username like \"${SR_username}%\""
        }
    }

    set SR_fname [reqGetArg SR_fname]
    if {[string length $SR_fname] > 0} {
        lappend where "[upper_q r.fname] = [upper_q '$SR_fname']"
    }

    set SR_lname [reqGetArg SR_lname]
    if {[string length $SR_lname] > 0} {
        lappend where [get_indexed_sql_query $SR_lname lname]
    }

    set SR_email [reqGetArg SR_email]
    if {[string length $SR_email] > 0} {
     	lappend where [get_indexed_sql_query "%$SR_email" email]
    }

    set SR_acct_no       [reqGetArg SR_acct_no]
    set SR_acct_no_exact [reqGetArg SR_acct_no_exact]
    if {[string length $SR_acct_no] > 0} {
        if {$SR_acct_no_exact == "Y"} {
            lappend where "c.acct_no = '$SR_acct_no'"
        } else {
			lappend where "c.acct_no like '$SR_acct_no%'"
        }
	}

    set SR_date_1     [reqGetArg SR_date_1]
    set SR_date_2     [reqGetArg SR_date_2]
    set SR_date_range [reqGetArg SR_date_range]

    if {$SR_date_range != ""} {
        set now_dt [clock format [clock seconds] -format %Y-%m-%d]
        foreach {Y M D} [split $now_dt -] { break }
        set SR_date_2 "$Y-$M-$D"
        if {$SR_date_range == "TD"} {
            set SR_date_1 "$Y-$M-$D"
        } elseif {$SR_date_range == "CM"} {
            set SR_date_1 "$Y-$M-01"
        } elseif {$SR_date_range == "YD"} {
            set SR_date_1 [date_days_ago $Y $M $D 1]
            set SR_date_2 $SR_date_1
        } elseif {$SR_date_range == "L3"} {
            set SR_date_1 [date_days_ago $Y $M $D 3]
        } elseif {$SR_date_range == "L7"} {
            set SR_date_1 [date_days_ago $Y $M $D 7]
        }
        append SR_date_1 " 00:00:00"
        append SR_date_2 " 23:59:59"
    }

	if {$SR_date_1 != ""} {
	    lappend where "l.start_time >= '$SR_date_1'"
	}
	if {$SR_date_2 != ""} {
    	lappend where "l.start_time <= '$SR_date_2'"
    }

	set SR_bet_min  [reqGetArg SR_bet_min]
	set SR_bet_max  [reqGetArg SR_bet_max]
	set SR_grp_min  [reqGetArg SR_grp_min]
	set SR_grp_max  [reqGetArg SR_grp_max]

	if {$SR_bet_min != ""} {
		lappend where "l.num_bets >= $SR_bet_min"
	}

	if {$SR_bet_max != ""} {
		lappend where "l.num_bets <= $SR_bet_max"
	}

	if {$SR_grp_min != ""} {
		lappend where "l.num_bet_grps >= $SR_grp_min"
	}

	if {$SR_grp_max != ""} {
		lappend where "l.num_bet_grps <= $SR_grp_max"
	}

    set SR_operator [reqGetArg SR_operator]
    if {$SR_operator != ""} {
		#operators may have apostrophe in name so using double quotes
        lappend where "u.username = \"$SR_operator\""
    }

    set SR_term_code [reqGetArg SR_term_code]
    if {$SR_term_code != ""} {
        lappend where "l.term_code = '$SR_term_code'"
    }

    set SR_cancel_code [reqGetArg SR_cancel_code]
    if {[string length $SR_cancel_code] > 0} {
        lappend where "l.cancel_code = '$SR_cancel_code'"
    }

	#
	# Channels:
	#
	if {([string length [set op [reqGetArg ChannelOp]]] > 0) &&
		([set numchannels [reqGetNumArgs ChannelName]] > 0)} {

		for {set n 0} {$n < $numchannels} {incr n} {
			lappend chan_list  [reqGetNthArg ChannelName $n]
		}

		if {$op == "0"} {
			set qop "not in "
		} else {
			set qop "in "
		}
		lappend where "l.source $qop ('[join $chan_list ',']')"
	}

    if {[llength $where]} {
        set where "and [join $where { and }]"
    }

	# Only return the first n items from this search.
	set first_n ""
	if {[set n [OT_CfgGet SELECT_FIRST_N 0]]} {
		set first_n " first $n "
	}

	set sql [subst {
		select $first_n
			l.call_id,
			l.oper_id,
			l.source,
			l.term_code,
			l.telephone,
			l.acct_id,
			l.start_time,
			l.end_time,
			l.num_bets,
			l.num_bet_grps,
			l.cancel_code,
			l.cancel_txt,
			u.username operator,
			c.cust_id,
			c.username,
			c.acct_no,
			c.elite,
			r.fname,
			r.lname
		from
			tCall l,
			tAcct a,
			tAdminUser u,
			tCustomer c,
			tCustomerReg r
		where
			l.oper_id     = u.user_id
		and l.acct_id     = a.acct_id
		and a.cust_id     = c.cust_id
		and a.cust_id     = r.cust_id
		and a.owner       <> 'D'
		    $where
		order by
			l.call_id
	}]
 
    set stmt [inf_prep_sql $DB $sql]
    set res  [inf_exec_stmt $stmt]
    inf_close_stmt $stmt

    tpSetVar NumCalls [set NumCalls [db_get_nrows $res]]

    global DATA

    array set DATA [list]

    set elite 0

    for {set r 0} {$r < $NumCalls} {incr r} {
        set DATA($r,acct_no)      [acct_no_enc  [db_get_col $res $r acct_no]]
	set DATA($r,cust_id)      [db_get_col $res $r cust_id]
	set DATA($r,username)     [db_get_col $res $r username]
	set DATA($r,fname)        [db_get_col $res $r fname]
	set DATA($r,lname)        [db_get_col $res $r lname]
	#set DATA($r,cr_date)      [db_get_col $res $r cr_date]
	set DATA($r,call_id)      [db_get_col $res $r call_id]
	set DATA($r,operator)     [db_get_col $res $r operator]
	set DATA($r,source)       [db_get_col $res $r source]
	set DATA($r,term_code)    [db_get_col $res $r term_code]
	set DATA($r,telephone)    [db_get_col $res $r telephone]
	set DATA($r,start_time)   [db_get_col $res $r start_time]
	set DATA($r,end_time)     [db_get_col $res $r end_time]
	set DATA($r,num_bets)     [db_get_col $res $r num_bets]
	set DATA($r,num_bet_grps) [db_get_col $res $r num_bet_grps]
	set DATA($r,cancel_code)  [db_get_col $res $r cancel_code]
	set DATA($r,cancel_txt)   [db_get_col $res $r cancel_txt]
	set DATA($r,elite)        [db_get_col $res $r elite]
	if {[db_get_col $res $r elite] == "Y"} {
		incr elite
	}
    }

    tpSetVar IS_ELITE $elite

    tpBindVar CustId     DATA cust_id      call_idx
    tpBindVar Username   DATA username     call_idx
    tpBindVar FName      DATA fname        call_idx
    tpBindVar LName      DATA lname        call_idx
    #tpBindVar Date       DATA cr_date      call_idx
    tpBindVar AcctNo     DATA acct_no      call_idx
    tpBindVar CallId     DATA call_id      call_idx
    tpBindVar Operator   DATA operator     call_idx
    tpBindVar Source     DATA source       call_idx
    tpBindVar TermCode   DATA term_code    call_idx
    tpBindVar Telephone  DATA telephone    call_idx
    tpBindVar StartTime  DATA start_time   call_idx
    tpBindVar EndTime    DATA end_time     call_idx
    tpBindVar BetNum     DATA num_bets     call_idx
    tpBindVar GrpNum     DATA num_bet_grps call_idx
    tpBindVar CancelCode DATA cancel_code  call_idx
    tpBindVar CancelText DATA cancel_txt   call_idx
    tpBindVar Elite      DATA elite        call_idx


    asPlayFile -nocache call/call_qry_list.html

    unset DATA

    db_close $res
}


#
# ----------------------------------------------------------------------------
# Update a specific payment - route to the appropriate handler based on
# the sort of payment
# ----------------------------------------------------------------------------
#
proc do_call args {

    if {[reqGetArg SubmitName] == "Back"} {
        do_call_query
        return
    }
}

}
