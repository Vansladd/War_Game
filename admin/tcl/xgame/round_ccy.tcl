# ==============================================================
# $Id: round_ccy.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

proc show_round_ccy {} {

    global XG_RS

    # default currency
    set sql {
	select default_ccy from tcontrol
    }
    set rs [xg_exec_qry $sql]
    set default_ccy [db_get_col $rs default_ccy]
    tpBindString default_ccy $default_ccy
    db_close $rs

    # available currencies
    set sql {
	select ccy_code from tCCY where status='A'
    }
    set rs [xg_exec_qry $sql]
    set nrows [db_get_nrows $rs]
    tpSetVar avail_nrows [expr "$nrows-1"]

    set i 0
    for {set r 0} {$r < $nrows} {incr r} {
	set tmp [db_get_col $rs $r ccy_code]
	if {$tmp!=$default_ccy} {
	    set XG_RS($i,avail_ccy_code) [db_get_col $rs $r ccy_code]
	    incr i
	}
    }
    tpBindVar avail_ccy_code XG_RS avail_ccy_code idx
    db_close $rs

    # contents of tXGameRoundCCY
    set sql {
	select * from tXGameRoundCCY
	order by ccy_code
    }
    set rs [xg_exec_qry $sql]
    set nrows [db_get_nrows $rs]
    xg_bind_rs $rs
    db_close $rs

    X_play_file round_ccy.html
}

proc add_round_ccy {} {

    set sql {
	insert into tXGameRoundCCY (round_exch_rate, ccy_code)
	values (?,?)
    }

    set round_exch_rate [reqGetArg round_exch_rate]
    
    set ccy_code [reqGetArg ccy_code]
    
    if {[regexp {^(([0-9]+\.?)|(\.))[0-9]*$} $round_exch_rate]} {
        set rs [xg_exec_qry $sql $round_exch_rate $ccy_code]
        db_close $rs
    }
    
    show_round_ccy

}

proc delete_round_ccy {} {

    set sql {
	delete from tXGameRoundCCY
	where ccy_code = ?
    }
    
    set rs [xg_exec_qry $sql [reqGetArg ccy_code]]
    db_close $rs

    show_round_ccy
}
