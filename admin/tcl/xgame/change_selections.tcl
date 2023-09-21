# ==============================================================
# $Id: change_selections.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

proc do_sub_change_selections {} {
    
    global DB

    set xgame_sub_id [reqGetArg xgame_sub_id]
    if {$xgame_sub_id==""} {
	# Don't want to change every subscription in the database!
	error "no sub_id specified" 
	return
    }

    set picks [naive_validate_selections]

    set sql1 {
	update tXGameSub set picks = ?
	where xgame_sub_id = ?
    }

    # I'm slightly scared by this query. I believe it's correct,
    # but I could do a lot of damage with it.

    set sql2 {
	update tXGameBet set picks = ?
	where xgame_sub_id = ?
	and settled = 'N'
	and output <> 'Y'
    }

    # do it

    set picks [join $picks "|"]
    
    inf_begin_tran $DB
    if [catch {
	set rs [xg_exec_qry $sql1 $picks $xgame_sub_id]
	db_close $rs
	set rs [xg_exec_qry $sql2 $picks $xgame_sub_id]
	db_close $rs
    } msg] {
	inf_rollback_tran$DB
	error $msg
    }
    inf_commit_tran $DB
    
    go_xgame_sub_query

}

proc naive_validate_selections {} {
    
    set sql {
	select d.num_min, d.num_max, d.num_picks_min, d.num_picks_max from
	tXGameSub s,
	tXGame    g,
	tXGameDef d
	where s.xgame_sub_id = ?
	and s.xgame_id = g.xgame_id
	and d.sort = g.sort
    }

    set rs [xg_exec_qry $sql [reqGetArg xgame_sub_id]]
    foreach c [db_get_colnames $rs] {
	set $c [db_get_col $rs $c]
    }
    db_close $rs

    set picks {}
    for {set i 0} {$i<$num_picks_max} {incr i} {
	set p [reqGetArg sel_$i]
	if {$p!=""} {
	    lappend picks $p
	    if {$p<"${num_min}.0" || $p>"${num_max}.0"} {
		error "Selection outside range"
	    }
	}
    }
    set picks [lsort -integer $picks]
    set picks [uniq $picks]

    if {[llength $picks]<$num_picks_min || [llength $picks]>$num_picks_max} {
	error "Wrong number of selections"
    }

    
    return $picks
}

proc uniq {in} {
    set out {}
    if {$in=={}} return $out
    set last "not[lindex $in 0]"
    foreach x $in {
	if {$last!=$x} {
	    lappend out $x
	}
	set last $x
    }
    return $out
}
