# ==============================================================
# $Id: gamedefstake.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

proc show_gamedef_stake {} {

    # default system ccy for informational purposes onlyy
    set sql {
		select 
			ccy_code, 
			ccy_name 
		from tcontrol, 
			tCCY
		where 
			tCCY.ccy_code = tcontrol.default_ccy
    }
	
    set rs [xg_exec_qry $sql [reqGetArg sort]]
    if [catch {tpBindString ccy_code "[db_get_col $rs ccy_code]: [db_get_col $rs ccy_name]"} msg] {
		tpBindString ccy_code "No system currency specified: $msg"
    }
    db_close $rs
	
	# is the game stake allowed to be continuous (or discrete)
    set sql {
		select
			stake_mode,
			min_stake,
			max_stake
		from tXGameDef
		where sort = ?
	}
	set rs [xg_exec_qry $sql [reqGetArg sort]]
	if {[db_get_col $rs stake_mode]=="C"} {
		tpSetVar CtsStakes 1
		tpBindString sort [reqGetArg sort]
		tpBindString StakeMode "C"
		tpBindString MinStake [db_get_col $rs min_stake]
		tpBindString MaxStake [db_get_col $rs max_stake]
		db_close $rs
	} else {
		tpSetVar CtsStakes 0
		db_close $rs
		# if discrete case
		set sql {
			select 
				stake 
			from txgamedefstake
			where sort = ?
			order by stake asc
    	}
    	tpBindString sort [reqGetArg sort]
    	set rs [xg_exec_qry $sql [reqGetArg sort]]
    	xg_bind_rs $rs gamedefstake
    	db_close $rs
    }
	
    X_play_file gamedefstake.html

}

proc delete_gamedef_stake {} {

    set sql {
	delete from tXGameDefStake
	where sort = ?
	and stake = ?
    }

    set rs [xg_exec_qry $sql [reqGetArg sort] [reqGetArg stake]]
    db_close $rs

    show_gamedef_stake

}

proc add_gamedef_stake {} {
    
    set sql {
	insert into tXGameDefStake (sort,stake)
	values (?,?)
    }

    set rs [xg_exec_qry $sql [reqGetArg sort] [reqGetArg stake]]
    db_close $rs
    
    show_gamedef_stake
}

proc modify_gamedef_stake {} {
	set sort		[reqGetArg sort]
	set stake_mode 	[reqGetArg stake_mode]
	set min_stake 	[reqGetArg min_stake]
	set max_stake	[reqGetArg max_stake]

	if {[regexp {[^0-9\.]} $min_stake]} {
		return [handle_err "Incorrect stake" "The Min Stake contained an invalid character."]
    }
	if {[regexp {[^0-9\.]} $max_stake]} {
		return [handle_err "Incorrect stake" "The Max Stake contained an invalid character."]
    }
	if {$min_stake > $max_stake} {
		return [handle_err "Incorrect stake" "The Min Stake should be less than or equal to Max Stake."]
    }
	
	set sql {
		update tXGameDef 
		set min_stake	= ?	,
			max_stake	= ?
		where sort = ? and
			stake_mode 	= ?
    }

    set rs [xg_exec_qry $sql $min_stake $max_stake $sort $stake_mode]
    db_close $rs

 	show_gamedef_stake
}
