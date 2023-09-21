# ==============================================================
# $Id: default_times.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

proc show_default_times {} {

    global DRAWS

    set sql {
		select
	 		name,	
			default_shut_at,
		 	default_draw_at,
			desc_id	
		from tXGameDrawDesc
		where sort = ?
		and status = 'A'
		order by desc_id
	}
	set sort [reqGetArg sort]
	set draws [xg_exec_qry $sql $sort]
	set num_draws [db_get_nrows $draws]
	
	for {set i 0} {$i < $num_draws} {incr i} {
		set DRAWS($i,name) [db_get_col $draws $i name]
		set DRAWS($i,default_shut_at) [db_get_col $draws $i default_shut_at]
		set DRAWS($i,default_draw_at) [db_get_col $draws $i default_draw_at]
	}
	
	tpSetVar NumDraws       $num_draws
	
	tpBindVar DrawName 	DRAWS name            draw_idx
	tpBindVar DefaultShutAt DRAWS default_shut_at draw_idx
	tpBindVar DefaultDrawAt DRAWS default_draw_at draw_idx

    	db_close $draws

	tpBindString sort $sort

	X_play_file default_times.html
}

proc add_default_time {} {
	
	set sql {
	 	update tXGameDrawDesc
		set default_shut_at = ?,
		    default_draw_at = ? 
		where sort = ?
		and   name = ?
	}

	for {set i 0} {$i < [reqGetArg num_draws]} {incr i} {	
		xg_exec_qry $sql [reqGetArg default_shut_at_$i] [reqGetArg default_draw_at_$i] [reqGetArg sort] [reqGetArg draw_$i]
	}

	show_default_times	
}

