# ==============================================================
# $Id: xgame_admin.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2003 Orbis Technology Ltd. All rights reserved.
# ==============================================================

set FullMonths(en) [list\
			xxx\
			January\
			February\
			March\
			April\
			May\
			June\
			July\
			August\
			September\
			October\
			November\
			December]

proc X_play_file {filename} {
    global XG_RS USE_COMPRESSION
	set tmp_compress $USE_COMPRESSION
	set USE_COMPRESSION 0
    catch {asPlayFile -nocache "xgame/$filename"} msg
	set USE_COMPRESSION $tmp_compress

}

# Wrapper to prep a statment, exec it, close statement
# and return results
proc xg_exec_qry args {
    global DB

    if {[llength $args]==0} {
	error "Usage: xg_exec_qry {sql} substvariable ..."
	return
    }
    set sql [lindex $args 0]

    set stmt [inf_prep_sql $DB $sql]
    set res [eval inf_exec_stmt $stmt [lrange $args 1 end]]
    inf_close_stmt $stmt
    return $res
}

proc bind_game_type_dropdown {} {
	global xgaQry
	global XGAME_TYPES

	if {[info exists XGAME_TYPES]} {
		unset XGAME_TYPES
	}


	if [catch {set rs [xg_exec_qry $xgaQry(get_gamedefs)]} msg] {
		return [handle_err "get gamedefs" "error retrieving gamedefs: $msg"]
	}

	set nrows [db_get_nrows $rs]

	tpSetVar NumGameTypes $nrows

	for {set i 0} {$i < $nrows} {incr i} {
		set XGAME_TYPES($i,sort) [db_get_col $rs $i sort]
		set XGAME_TYPES($i,name) [db_get_col $rs $i name]
	}

	tpBindVar GameSort XGAME_TYPES sort game_type_idx
	tpBindVar GameName XGAME_TYPES name game_type_idx

	db_close $rs
}


proc H_GoXGameFind args {
	global XGAME_TYPES

	bind_game_type_dropdown

	X_play_file findgame.html
}

proc H_DoXGameFind args {
    set submitname [reqGetArg GameName]

    if {$submitname == "Show Matching Games" || $submitname == "Update Matching Games"} {
		show_matching_games
    }
    if {$submitname == "Add New Game"} {
		H_GoEditGame
    }
    if {$submitname == "Edit Game"} {
		show_gamedef
		return
    }
    if {$submitname == "Edit Default Draw Times"} {
		show_default_times
    }
    if {$submitname == "Export Files"} {
		H_GoViewExportFiles
    }
    if {$submitname == "Import Files"} {
		reqSetArg upload_type "EVT"
		ADMIN::UPLOAD::go_upload
    }
    if {$submitname == "Price Matrix"} {
		show_prices
    }

    if {$submitname == "View Game Def"} {
		go_gametype view
    }

    if {$submitname == "Add New Game Def"} {
		go_gametype add
    }

    if {$submitname == "Edit Game Def"} {
		go_gametype edit
    }

    if {$submitname == "Edit Draw Desc"} {
		edit_drawdesc [reqGetArg sort]
    }
}


proc go_gametype mode {

    tpBindString MODE $mode
    set submit [reqGetArg Submit]

    if {$mode=="add" && $submit=="Submit"} {
        add_gametype
    } elseif {$mode=="edit"} {
        edit_gametype
    } elseif {$mode=="view"} {
        view_gametype [reqGetArg sort]
    }

    X_play_file editgametype.html
}

proc validate_drawdesc {sort name desc  default_draw_at  default_shut_at status} {

    if {$sort==""} {
        handle_err "sort must not be blank" "The field was blank"
        return false
    }

    if {$name==""} {
        handle_err "name must not be blank" "The field was blank"
        return false
    }

    if {$desc==""} {
        handle_err "description must not be blank" "The field was blank"
        return false
    }

    return true
}

proc edit_drawdesc_channels {id} {
	global xgaQry

	if {[reqGetArg channel_mode]=="edit"} {
		set channels [make_channel_str]

		if [catch {set rs [xg_exec_qry $xgaQry(edit_drawdesc_channels) $channels $id]} msg] {
			return [handle_err "get_drawdescs_for_sort" "error: $msg"]
		}

		db_close $rs
	}

	if [catch {set rs [xg_exec_qry $xgaQry(get_drawdescs_for_id) $id]} msg] {
        return [handle_err "get_drawdescs_for_sort" "error: $msg"]
    }

    set nrows [db_get_nrows $rs]

	if {$nrows != 1} {
		return [handle_err "get_drawdescs_for_id" "error: $msg"]
	}

	make_channel_binds [db_get_col $rs channels] "-"

	tpBindString desc_id [db_get_col $rs desc_id]
	tpBindString sort [db_get_col $rs sort]
	tpBindString desc [db_get_col $rs desc]

	db_close $rs

	X_play_file editdrawdesc_channels.html
}

proc edit_drawdesc sort {
	global xgaQry
	global DRAW_DESCS

	if {[info exists DRAW_DESCS]} {
		unset DRAW_DESCS
	}

	set mode [reqGetArg mode]
	set input_mode "add"

	if {$mode=="edit_channels"} {
		set id 	[reqGetArg id]
		edit_drawdesc_channels $id
		return
    	} elseif {$mode=="add"} {
		set sort            [reqGetArg sort]
		set name            [reqGetArg name]
		set desc            [reqGetArg desc]
		set default_draw_at [reqGetArg default_draw_at]
		set default_shut_at [reqGetArg default_shut_at]
		set status          [reqGetArg status]
		set day             [reqGetArg day]
		set shut_day        [reqGetArg shut_day]

		if {[validate_drawdesc $sort $name $desc $default_draw_at $default_shut_at $status]} {
			tpSetVar updateSucessful "true"
			if [catch {set rs [xg_exec_qry $xgaQry(insert_drawdesc) $sort $name $desc $default_draw_at $default_shut_at $status $day $shut_day]} msg] {
			return [handle_err "get_drawdescs_for_sort" "error: $msg"]
            		}
        	} else {
			tpSetVar updateSucessful "false"
		}
	} elseif {$mode=="view"} {
		set id [reqGetArg id]
		set input_mode "edit"
	} elseif {$mode=="do_upd"} {
		tpSetVar updateSuccesful "false"

		set id              [reqGetArg id]
		set name            [reqGetArg upd_name]
		set sort            [reqGetArg sort]
		set desc            [reqGetArg upd_desc]
		set day             [reqGetArg upd_day]
		set default_draw_at [reqGetArg upd_default_draw_at]
		set default_shut_at [reqGetArg upd_default_shut_at]
		set status          [reqGetArg upd_status]

		if {[validate_drawdesc $sort $name $desc $default_draw_at $default_shut_at $status]} {
			if {[catch {xg_exec_qry $xgaQry(edit_drawdesc)  $name $desc $default_draw_at $default_shut_at $status $day $id}]} {

			} else {
				tpSetVar updateSucessful "true"
              		}
		 }

	} elseif {$mode=="delete"} {
		set id [reqGetArg id]

		if [catch {set rs [xg_exec_qry $xgaQry(delete_drawdesc) $id]} msg] {
			return [handle_err "delete drawdesc" "error: $msg"]
		}
	}

	if [catch {set rs [xg_exec_qry $xgaQry(get_drawdescs_for_sort) $sort]} msg] {
		return [handle_err "get_drawdescs_for_sort" "error: $msg"]
	}

	set nrows [db_get_nrows $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		set DRAW_DESCS($r,desc_id)            [db_get_col $rs $r desc_id]
		set DRAW_DESCS($r,sort)               [db_get_col $rs $r sort]
		set DRAW_DESCS($r,name)               [db_get_col $rs $r name]
		set DRAW_DESCS($r,desc)               [db_get_col $rs $r desc]
		set DRAW_DESCS($r,default_draw_at)    [db_get_col $rs $r default_draw_at]
		set DRAW_DESCS($r,default_shut_at)    [db_get_col $rs $r default_shut_at]
		set DRAW_DESCS($r,status)             [db_get_col $rs $r status]
		set DRAW_DESCS($r,day)                [db_get_col $rs $r day]
		set DRAW_DESCS($r,shut_day)           [db_get_col $rs $r shut_day]

		if {$mode == "view" && [db_get_col $rs $r desc_id] == $id } {
			tpSetVar row_to_edit $r
		}
	}

	db_close $rs

	tpBindString input_mode $input_mode
	tpSetVar i_mode $input_mode

	tpSetVar rows $nrows
	tpBindString sort $sort

	tpBindVar DESC_ID       DRAW_DESCS desc_id          row_idx
	tpBindVar DESC_SORT     DRAW_DESCS sort             row_idx
	tpBindVar DESC_NAME     DRAW_DESCS name             row_idx
	tpBindVar DESC_DESC     DRAW_DESCS desc             row_idx
	tpBindVar DESC_DRAW_AT  DRAW_DESCS default_draw_at  row_idx
	tpBindVar DESC_SHUT_AT  DRAW_DESCS default_shut_at  row_idx
	tpBindVar DESC_STATUS   DRAW_DESCS status           row_idx
	tpBindVar DESC_CHANNELS DRAW_DESCS channels         row_idx
	tpBindVar DESC_DAY      DRAW_DESCS day              row_idx
	tpBindVar DESC_SHUT_DAY DRAW_DESCS shut_day         row_idx

	X_play_file editdrawdesc.html
}

proc validate_gametype {name num_picks_max num_picks_min num_results_max num_results_min num_min num_max desc min_stake max_stake stake_mode max_payout coupon_max_lines sort external_settle max_selns min_subs max_subs} {

    if {![regexp {^[0-9]+$} $num_picks_max]} {
		handle_err "Incorrect number of picks max." "The field contained an invalid character."
        return false
    }

    if {![regexp {^[0-9]+$} $num_picks_min]} {
		handle_err "Incorrect number of picks min." "The field contained an invalid character."
        return false
    }

    if {![regexp {^[0-9]+$} $num_results_max]} {
		handle_err "Incorrect number of results max." "The field contained an invalid character."
        return false
    }

    if {![regexp {^[0-9]+$} $num_results_min]} {
		handle_err "Incorrect number of results min." "The field contained an invalid character."
        return false
    }

    if {![regexp {^[0-9]+$} $num_min]} {
		handle_err "Incorrect number of balls min." "The field contained an invalid character."
        return false
    }

    if {![regexp {^^[0-9]+$} $num_max]} {
		handle_err "Incorrect number of balls max." "The field contained an invalid character."
        return false
    }

    if {![regexp {^[0-9]+$} $coupon_max_lines]} {
		handle_err "Incorrect number of coupon max lines." "The field contained an invalid character."
        return false
    }

    if {![regexp {^[0-9]+$} $max_selns]} {
		handle_err "Incorrect number of max selns." "The field contained an invalid character."
        return false
    }

    if {![regexp {^[0-9]+$} $min_subs]} {
		handle_err "Incorrect number of min subs." "The field contained an invalid character."
        return false
    }

    if {![regexp {^[0-9]+$} $max_subs]} {
		handle_err "Incorrect number of max subs." "The field contained an invalid character."
        return false
    }

    if {$sort==""} {
        handle_err "sort must not be blank" "The field was blank"
        return false
    }

    if {[string length $sort]>10} {
        handle_err "sort must not be greater than 10 charachters" "The field was too long"
        return false
    }

    if {$name==""} {
        handle_err "name must not be blank" "The field was blank"
        return false
    }

    if {$desc==""} {
        handle_err "desc must not be blank" "The field was blank"
        return false
    }

    if {$stake_mode!="D" && $stake_mode!="C"} {
        handle_err "stake mode must be either D or C" "The field contained an invalid character: $stake_mode"
        return false
    }

    if {$stake_mode=="C"} {
        if {![regexp {^(([0-9]+\.?)|(\.))[0-9]*$} $max_stake]} {
            handle_err "Incorrect max stake." "The field contained an invalid character."
            return false
        }

        if {![regexp {^(([0-9]+\.?)|(\.))[0-9]*$} $min_stake]} {
            handle_err "Incorrect min stake." "The field contained an invalid character."
            return false
        }
    }

    if {$stake_mode=="D"} {
        if {$max_stake!=""} {
            handle_err "Incorrect max stake." "The field is not required"
            return false
        }

        if {$min_stake!=""} {
            handle_err "Incorrect min stake." "The field is not required"
            return false
        }
    }

    if {$external_settle!="Y" && $external_settle!="N"} {
        handle_err "external setttle must either en Y or N" "The field contained an invalid character."
        return false
    }

    return true
}

proc add_gametype args {
    global xgaQry

    set sort               [reqGetArg sort]
    set name               [reqGetArg name]
    set num_picks_max      [reqGetArg num_picks_max]
    set num_picks_min      [reqGetArg num_picks_min]
    set num_results_max    [reqGetArg num_results_max]
    set num_results_min    [reqGetArg num_results_min]
    set num_min            [reqGetArg num_min]
    set num_max            [reqGetArg num_max]
    set desc               [reqGetArg desc]
    set min_stake          [reqGetArg min_stake]
    set max_stake          [reqGetArg max_stake]
    set min_subs           [reqGetArg min_subs]
    set max_subs           [reqGetArg max_subs]
    set stake_mode         [reqGetArg stake_mode]
    set max_payout         [reqGetArg max_payout]
    set coupon_max_lines   [reqGetArg coupon_max_lines]
    set external_settle    [reqGetArg external_settle]
    set max_selns          [reqGetArg max_selns]
    set game_type          [reqGetArg game_type]
    set results            [reqGetArg results]
	set rules              [reqGetArg rules]
	set flag_gif           [reqGetArg flag_gif]
    set disp_order         [reqGetArg disp_order]

    if {[validate_gametype $name $num_picks_max $num_picks_min $num_results_max $num_results_min $num_min $num_max $desc $min_stake $max_stake $stake_mode $max_payout $coupon_max_lines $sort $external_settle $max_selns $min_subs $max_subs]=="false"} {
        tpSetVar updateSucessful "false"
        return
    }

    OT_LogWrite 1 "Adding gamedef (xgaQry(insert_gamedef)) $name $num_picks_max $num_picks_min $num_results_max $num_results_min $num_min $num_max $desc $min_stake $max_stake $stake_mode $max_payout $coupon_max_lines $sort N $external_settle N $max_selns $min_subs $max_subs"

    if [catch {set rs [xg_exec_qry $xgaQry(insert_gamedef) $name $num_picks_max $num_picks_min $num_results_max $num_results_min $num_min $num_max $desc $min_stake $max_stake $stake_mode $max_payout $coupon_max_lines $sort "N" $external_settle "N" $max_selns $game_type $results $rules $flag_gif $min_subs $max_subs $disp_order]} msg] {
		tpSetVar updateSucessful "false"
        return [handle_err "insert_gamedef" "error: $msg"]

    }

    OT_LogWrite 1 "Added Gamedef"

    db_close $rs

    view_gametype $sort

    tpSetVar updateSucessful "true"
}

proc update_max_mins {sort default_max default_min max_selns} {
    global xgaQry
    global BET_TYPES

	if {[info exists BET_TYPES]} {
		unset BET_TYPES
	}

    prepare_bettypes_array $max_selns

    set bet_type_count [reqGetArg bet_type_count]

    if [catch {set rs [xg_exec_qry $xgaQry(remove_all_min_max) $sort]} msg] {
        tpSetVar updateSucessful "false"
        return [handle_err "remove_all_min_max" "error: $msg"]
    }

    for {set r 0} {$r < $bet_type_count} {incr r} {
        set bt_arg_name $r
        append bt_arg_name "_type"

        set max_arg_name $r
        append max_arg_name "_max"

        set min_arg_name $r
        append min_arg_name "_min"

        set bet_type    [reqGetArg $bt_arg_name]
        set max_bet     [reqGetArg $max_arg_name]
        set min_bet     [reqGetArg $min_arg_name]

        set count $BET_TYPES(0,count)
        set found "false"
        for {set n 0} {$n < $count} {incr n} {
            set tempBetType $BET_TYPES($n,bet_type)


            if {$tempBetType==$bet_type} {
                set found "true"
            }
        }

        if {$max_bet==""} {
            set max_bet $default_max
        }

        if {$min_bet==""} {
            set min_bet $default_min
        }

        if {$found=="true"} {
            if {[validate_max_min $bet_type $max_bet $min_bet]} {
                if [catch {set rs [xg_exec_qry $xgaQry(insert_min_max) $bet_type $sort $min_bet $max_bet]} msg] {
                    tpSetVar updateSucessful "false"
                    return [handle_err "insert_min_max" "error: $msg"]
                } else {
                    OT_LogWrite 1 "VALIDATED"
                }
            }
        }
    }

    db_close $rs
}

proc validate_max_min {bet_type max_bet min_bet} {

    if {![regexp {^(([0-9]+\.?)|(\.))[0-9]*$} $min_bet]} {
        return false
    }

    if {![regexp {^(([0-9]+\.?)|(\.))[0-9]*$} $max_bet]} {
        return false
    }

    if {$bet_type==""} {
        handle_err "bet type must not be blank" "The field was blank"
        return false
    }
    return true
}

proc edit_gametype args {
    global xgaQry

    set sort               [reqGetArg sort]
    set name               [reqGetArg name]
    set num_picks_max      [reqGetArg num_picks_max]
    set num_picks_min      [reqGetArg num_picks_min]
    set num_results_max    [reqGetArg num_results_max]
    set num_results_min    [reqGetArg num_results_min]
    set num_min            [reqGetArg num_min]
    set num_max            [reqGetArg num_max]
    set desc               [reqGetArg desc]
    set min_stake          [reqGetArg min_stake]
    set max_stake          [reqGetArg max_stake]
    set min_subs           [reqGetArg min_subs]
    set max_subs           [reqGetArg max_subs]
    set stake_mode         [reqGetArg stake_mode]
    set max_payout         [reqGetArg max_payout]
    set coupon_max_lines   [reqGetArg coupon_max_lines]
    set external_settle    [reqGetArg external_settle]
    set max_selns          [reqGetArg max_selns]
    set game_type          [reqGetArg game_type]
    set results            [reqGetArg results]
	set rules              [reqGetArg rules]
	set flag_gif           [reqGetArg flag_gif]
    set disp_order         [reqGetArg disp_order]

    if {[validate_gametype $name $num_picks_max $num_picks_min $num_results_max $num_results_min $num_min $num_max $desc $min_stake $max_stake $stake_mode $max_payout $coupon_max_lines $sort $external_settle $max_selns $min_subs $max_subs]=="false"} {
        tpSetVar updateSucessful "false"
        return
    }

    OT_LogWrite 1 "Editing gamedef (xgaQry(edit_gamedef)) $name $num_picks_max $num_picks_min $num_results_max $num_results_min $num_min $num_max $desc $min_stake $max_stake $stake_mode $max_payout $coupon_max_lines $external_settle $max_selns $min_subs $max_subs $sort"

    if [catch {set rs [xg_exec_qry $xgaQry(edit_gamedef) $name $num_picks_max $num_picks_min $num_results_max $num_results_min $num_min $num_max $desc $min_stake $max_stake $stake_mode $max_payout $coupon_max_lines $external_settle $max_selns $game_type $results $rules $flag_gif $min_subs $max_subs $disp_order $sort]} msg] {
		tpSetVar updateSucessful "false"
        return [handle_err "edit_gamedef" "error: $msg"]
    }

    db_close $rs

    update_max_mins $sort $max_stake $min_stake $max_selns

    view_gametype $sort

    tpSetVar updateSucessful "true"
}

proc prepare_bettypes_array num_selns {
    global xgaQry
    global BET_TYPES

	if {[info exists BET_TYPES]} {
		unset BET_TYPES
	}

    if [catch {set rs [xg_exec_qry $xgaQry(get_bet_types) $num_selns]} msg] {
        return [handle_err "get_bet_types" "error: $msg"]
    }

    set nrows [db_get_nrows $rs]
    set BET_TYPES(0,count) $nrows

    OT_LogWrite 1 "BET TYPE COUNT $nrows $BET_TYPES(0,count)"

    for {set r 0} {$r < $nrows} {incr r} {
        set BET_TYPES($r,bet_type) [db_get_col $rs $r bet_type]
    }
}

proc view_gametype xgame_sort {
    global xgaQry
    global BET_TYPES
    global MIN_MAX

	if {[info exists BET_TYPES]} {
		unset BET_TYPES
	}

	if {[info exists MIN_MAX]} {
		unset MIN_MAX
	}

    if [catch {set rs [xg_exec_qry $xgaQry(get_gamedef) $xgame_sort]} msg] {
		return [handle_err "get_gamedef" "error: $msg"]
    }

    tpBindString sort               [db_get_col $rs 0 sort]
    tpBindString name               [db_get_col $rs 0 name]
    tpBindString num_picks_max      [db_get_col $rs 0 num_picks_max]
    tpBindString num_picks_min      [db_get_col $rs 0 num_picks_min]
    tpBindString num_results_max    [db_get_col $rs 0 num_results_max]
    tpBindString num_results_min    [db_get_col $rs 0 num_results_min]
    tpBindString conf_needed        [db_get_col $rs 0 conf_needed]
    tpBindString external_settle    [db_get_col $rs 0 external_settle]
    tpBindString has_balls          [db_get_col $rs 0 has_balls]
    tpBindString num_min            [db_get_col $rs 0 num_min]
    tpBindString num_max            [db_get_col $rs 0 num_max]
    tpBindString single_bet_alarm   [db_get_col $rs 0 single_bet_alarm]
    tpBindString desc               [db_get_col $rs 0 desc]
    tpBindString min_stake          [db_get_col $rs 0 min_stake]
    tpBindString max_stake          [db_get_col $rs 0 max_stake]
    tpBindString min_subs           [db_get_col $rs 0 min_subs]
    tpBindString max_subs           [db_get_col $rs 0 max_subs]
    tpBindString stake_mode         [db_get_col $rs 0 stake_mode]
    tpBindString max_card_payout    [db_get_col $rs 0 max_card_payout]
    tpBindString cheque_payout_msg  [db_get_col $rs 0 cheque_payout_msg]
    tpBindString max_payout         [db_get_col $rs 0 max_payout]
    tpBindString channels           [db_get_col $rs 0 channels]
    tpBindString xgame_attr         [db_get_col $rs 0 xgame_attr]
    tpBindString coupon_max_lines   [db_get_col $rs 0 coupon_max_lines]
    tpBindString results            [db_get_col $rs 0 result_url]
	tpBindString rules              [db_get_col $rs 0 rules_url]
	tpBindString flag_gif           [db_get_col $rs 0 flag_gif]
    tpBindString game_type          [db_get_col $rs 0 game_type]
    tpBindString disp_order         [db_get_col $rs 0 disp_order]

    tpSetVar stakeModeCur [db_get_col $rs 0 stake_mode]
    tpSetVar extSettleCur [db_get_col $rs 0 external_settle]

    set max_selns          [db_get_col $rs 0 max_selns]

    tpBindString max_selns          $max_selns

    set max_stake [db_get_col $rs 0 max_stake]
    set min_stake [db_get_col $rs 0 min_stake]

    tpBindString MODE edit
    tpSetVar mode edit
    tpSetVar stakeMode [db_get_col $rs 0 stake_mode]

    if {![regexp {^[0-9]+$} $max_selns]} {
        set max_selns 0
    }

    prepare_bettypes_array [db_get_col $rs 0 max_selns]

    db_close $rs

    set bet_type_count $BET_TYPES(0,count)

    set min_max_stored 0

    for {set r 0} {$r < $bet_type_count} {incr r} {

        set bet_type $BET_TYPES($r,bet_type)

        if [catch {set rs [xg_exec_qry $xgaQry(get_min_max) $xgame_sort $bet_type]} msg] {
            return [handle_err "get_max_min_picks" "error: $msg"]
        }

        set nrows [db_get_nrows $rs]

        if {$nrows>0} {
            incr min_max_stored
            set temp_max     [db_get_col $rs 0 max_bet]
            set temp_min     [db_get_col $rs 0 min_bet]
        } else {
            set temp_max     $max_stake
            set temp_min     $min_stake
        }

        set MIN_MAX($r,bet_type)    $bet_type
        set MIN_MAX($r,max_bet)     $temp_max
        set MIN_MAX($r,min_bet)     $temp_min
    }
    if {$min_max_stored == $bet_type_count} {
        tpSetVar min_max_stored "true"
    } else {
        tpSetVar min_max_stored "false"
    }

    OT_LogWrite 1 "STORED: $min_max_stored"

    tpSetVar bet_type_count $bet_type_count

    tpBindVar TYPE MIN_MAX bet_type row_idx
    tpBindVar MAX  MIN_MAX max_bet  row_idx
    tpBindVar MIN  MIN_MAX min_bet  row_idx
}

proc get_prices_for_matrix {xgame_sort} {
    global xgaQry

    global PRICES_MATRIX

	if {[info exists PRICES_MATRIX]} {
		unset PRICES_MATRIX
	}

    if [catch {set rs [xg_exec_qry $xgaQry(get_max_min_picks) $xgame_sort]} msg] {
		return [handle_err "get_max_min_picks" "error: $msg"]
    }

    set maxpicks [db_get_col $rs 0 num_picks_max]
    set minpicks [db_get_col $rs 0 num_picks_min]


    for {set y 0} {$y < $maxpicks} {incr y} {
        for {set x 0} {$x < $maxpicks} {incr x} {
            set PRICES_MATRIX($x,$y,price) ""
        }
    }

    if [catch {set rs [xg_exec_qry $xgaQry(get_prices) $xgame_sort]} msg] {
		return [handle_err "get_prices" "error: $msg"]
    }

    set nrows [db_get_nrows $rs]

    for {set r 0} {$r < $nrows} {incr r} {
        set xval [db_get_col $rs $r num_picks]
        set yval [db_get_col $rs $r num_correct]


        if {[regexp {^[0-9]+$} $yval] && [regexp {^[0-9]+$} $xval]} {
            incr xval -1
            incr yval -1

            set price [mk_price [db_get_col $rs $r price_num] [db_get_col $rs $r price_den]]
            set PRICES_MATRIX($xval,$yval,price) $price
        }
    }

    db_close $rs

    tpSetVar maxPicks $maxpicks
    tpSetVar minPicks $minpicks

    tpBindVar MATRIX PRICES_MATRIX price x_idx y_idx

}

proc show_prices args {
    edit_prices [reqGetArg sort]
}

proc add_price {sort num_correct num_picks price_num price_den} {
    global xgaQry

    OT_LogWrite 1 "Adding Price $sort $num_picks $num_correct $price_num $price_den"

    if [catch {set rs [xg_exec_qry $xgaQry(add_price) $sort $num_picks $num_correct $price_num $price_den]} msg] {
		handle_err "add_price" "error: $msg"
        return "error"
    }

    db_close $rs
}

proc delete_all_prices {sort} {
    global xgaQry

    OT_LogWrite 1 "Deleteing Prices $sort"

    if [catch {set rs [xg_exec_qry $xgaQry(delete_all_prices) $sort]} msg] {
        handle_err "delete_all_prices" "error: $msg"
        return "error"
    }

    db_close $rs
}

proc update_prices_from_req {sort} {
    OT_LogWrite 1 "updating Prices for $sort"

    global DB

    inf_begin_tran $DB

    set executed [delete_all_prices $sort]

    if {$executed=="error"} {
        inf_rollback_tran $DB
        return
    }

    set maxpicks [reqGetArg maxPicks]

    for {set y 0} {$y < $maxpicks} {incr y} {
        for {set x 0} {$x < $maxpicks} {incr x} {
            set inputName "x_"
            append inputName $x
            append inputName "_y_"
            append inputName $y

            set inputValue [reqGetArg $inputName]

            set numP [expr $x+1]

            set numC [expr $y+1]

            if {$inputValue!=""} {


                if [catch {set price_parts [get_price_parts $inputValue]} msg] {
                    handle_err "invalid price" "number correct: $numC number picked: $numP"
                    inf_rollback_tran $DB
                    return
                }

                set num [lindex $price_parts 0]
                set den [lindex $price_parts 1]

				if {$num < 1 || $den < 1} {
					handle_err "invalid price" "number correct: $numC number picked: $numP"
                    inf_rollback_tran $DB
                    return
				}

                set executed [add_price $sort $numC $numP $num $den]

                if {$executed=="error"} {
                    inf_rollback_tran $DB
                    return
                }
            }
        }
    }

    tpBindString success "Prices Updated"

    inf_commit_tran $DB
}

proc edit_prices {xgame_sort} {
    global xgaQry

    tpBindString sort $xgame_sort

    set submit [reqGetArg Submit]

    if {$submit=="Submit"} {
        update_prices_from_req $xgame_sort
    }

    get_prices_for_matrix $xgame_sort

    X_play_file showprices.html
}

proc H_GoSettleBets {xgame_id} {
    global xgaQry


    if [catch {set rs [xg_exec_qry $xgaQry(game_detail) $xgame_id]} msg] {
		return [handle_err "game_detail" "error: $msg"]
    }
	set external_settle [db_get_col $rs 0 external_settle]
    db_close $rs

	OT_LogWrite 1 "Attempting to use internal settler on xgame_id $xgame_id"
	OT_LogWrite 1 "xgame_id $xgame_id external_settle = $external_settle"

	if {$external_settle == "N"} {
		## internal_settle $xgame_id
		## useing new settlement code
		internal_settle_with_bet_types $xgame_id
	}
}

proc H_GoEditGameStatus {} {

	global DB

	set submit [ob_chk::get_arg SubmitName -on_err "" \
				{EXACT -args {"Update All" "Activate All" "Suspend All"}}]

	if {$submit == "Update All"} {

		set ids ""
		set old_status ""
		set status ""

		#
		# Get all game ids and statuses to be updated
		#
		for {set i 0} { $i < [ob_chk::get_arg nrows -on_err -1 {INT}]} {incr i} {
			set id     [ob_chk::get_arg xgame_id_$i -on_err -1 {UINT}]
			set old_st [ob_chk::get_arg old_game_status_$i -on_err "" {EXACT -args {A S V}}]
			set st     [ob_chk::get_arg game_status_$i -on_err "" {EXACT -args {A S V}}]
			lappend ids $id
			lappend old_status $old_st
			lappend status $st

			if {[OT_CfgGet XG_HONOUR_SUBS_ON_ACTIVATE "0"]} {
				##
				## if this game is being activated
				## first thing to do is to honour any subs which may be stored
				## only do this if the game is being activated or starting off activated
				##
				if {$st == "A" && $st != $old_st} {
					process_subs_for_xgame $id 0
					tpSetVar tried_to_process_subs 1
				}
			}
		}

		set active_ids ""
		set suspended_ids ""
		set voided_ids ""

		for {set i 0} { $i < [ob_chk::get_arg nrows -on_err -1 {INT}]} {incr i} {
			if {[lindex $old_status $i] != [lindex $status $i]} {
				if {[lindex $status $i] == "A"} {
					lappend active_ids [lindex $ids $i]
				} elseif {[lindex $status $i] == "S"} {
					lappend suspended_ids [lindex $ids $i]
				} elseif {[lindex $status $i] == "V"} {
					lappend voided_ids [lindex $ids $i]
				}
			}
		}

		if {[llength $active_ids] > 0} {
			set active_ids "[join $active_ids {, }]"
			set active_ids "( $active_ids )"
			set sql_a [subst {
				update tXgame
					set status = 'A'
					where xgame_id in $active_ids
			}]
			set stmt_a [inf_prep_sql $DB $sql_a]
			set res [eval inf_exec_stmt $stmt_a]
			inf_close_stmt $stmt_a
		}
		if {[llength $suspended_ids] > 0} {
			set suspended_ids "[join $suspended_ids {, }]"
			set suspended_ids "( $suspended_ids )"
			set sql_s [subst {
				update tXgame
					set status = 'S'
					where xgame_id in $suspended_ids
			}]
			set stmt_s [inf_prep_sql $DB $sql_s]
			set res [eval inf_exec_stmt $stmt_s]
			inf_close_stmt $stmt_s
		}
		if {[llength $voided_ids] > 0} {
			set voided_ids "[join $voided_ids {, }]"
			set voided_ids "( $voided_ids )"
			set sql_v [subst {
				update tXgame
					set status = 'V'
					where xgame_id in $voided_ids
			}]
			set stmt_v [inf_prep_sql $DB $sql_v]
			set res [eval inf_exec_stmt $stmt_v]
			inf_close_stmt $stmt_v
		}
	} elseif {$submit == "Activate All"} {

		set ids ""

		for {set i 0} { $i < [ob_chk::get_arg nrows -on_err -1 {INT}]} {incr i} {
			set id [ob_chk::get_arg xgame_id_$i -on_err -1 {UINT}]
			set old_status [ob_chk::get_arg old_game_status_$i -on_err "" {EXACT -args {A S V}}]
			lappend ids $id

			if {[OT_CfgGet XG_HONOUR_SUBS_ON_ACTIVATE "0"]} {
					##
					## if this game is being activated
					## first thing to do is to honour any subs which may be stored
					## only do this if the game is being activated or starting off activated
					##
					if {$old_status != "A"} {
						process_subs_for_xgame $id 0
						tpSetVar tried_to_process_subs 1
					}
				}
			}

		ob_log::write INFO {Activating games: $ids}

		set ids "[join $ids {, }]"
		set ids "( $ids )"

		set sql [subst {
			update tXgame
				set status = 'A'
				where xgame_id in $ids
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res [eval inf_exec_stmt $stmt]
		inf_close_stmt $stmt

	} elseif {$submit == "Suspend All"} {

		set ids ""

		for {set i 0} { $i < [ob_chk::get_arg nrows -on_err -1 {UINT}]} {incr i} {
			set id [ob_chk::get_arg xgame_id_$i -on_err -1 {UINT}]
			lappend ids $id
		}

		ob_log::write INFO {Suspending games: $ids}
		set ids "[join $ids {, }]"
		set ids "( $ids )"

		set sql [subst {
			update tXgame
				set status = 'S'
				where xgame_id in $ids
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res [eval inf_exec_stmt $stmt]
		inf_close_stmt $stmt

	}

	#
	# Pass in original search data to take us back to the results page
	#
	tpBindString EarliestDate [ob_chk::get_arg EarliestDate -on_err "" {RE -args {[A-z0-9\s+-]+}}]
	tpBindString LatestDate   [ob_chk::get_arg LatestDate -on_err "" {RE -args {[A-z0-9\s+-]+}}]
	tpBindString sort         [ob_chk::get_arg sort -on_err "" {ALNUM}]
	tpBindString SelectStatus [ob_chk::get_arg SelectStatus -on_err "" {EXACT -args {A S V}}]
	reqSetArg GameName "Update Matching Games"

	show_matching_games

}

# Unsettle lottery bets
#
proc H_GoUnsettleBets {xgame_id} {
	global xgaQry USERID

	OT_LogWrite 1 "Attempting to use unsettler on xgame_id $xgame_id"
	if [catch {set rs [xg_exec_qry $xgaQry(unsettle_game) $xgame_id $USERID]} msg] {
		return [handle_err "game_detail" "error: $msg"]
	}

	db_close $rs

	H_GoXGameFind
}

proc H_GoEditGame {{xgame_id_manual ""}} {

    global xgaQry

    set xgame_id [ob_chk::get_arg xgame_id -on_err "" {UINT}]

    if {$xgame_id_manual!=""} {
		set xgame_id $xgame_id_manual
    }

    if {$xgame_id != ""} {

		if [catch {set rs_bets [xg_exec_qry $xgaQry(count_bets) $xgame_id]} msg] {
			return [handle_err "count_bets" "error: $msg"]
		}
		set num_bets [db_get_col $rs_bets 0 num_bets]
		db_close $rs_bets

		if [catch {set rs_bets [xg_exec_qry $xgaQry(count_unsettled_bets) $xgame_id]} msg] {
			 return [handle_err "count_settled_bets" "error: $msg"]
		}

		set num_unsettled_bets [db_get_col $rs_bets 0 num_unsettled]
		db_close $rs_bets

		tpBindString total_bets $num_bets

		tpBindString settled_bets [expr {$num_bets-$num_unsettled_bets}]


		# show unsettle button when there are settled bets.
		if {[expr {$num_bets-$num_unsettled_bets}] > 0} {
			tpSetVar hasSettledBets 1
		}

		if [catch {set rs [xg_exec_qry $xgaQry(game_detail) $xgame_id]} msg] {
		    return [handle_err "game_detail" "error: $msg"]
		}

		foreach c {xgame_id sort comp_no open_at shut_at draw_at status desc misc_desc name} {
		    tpBindString [string toupper $c] [db_get_col $rs 0 $c]
		}

		tpSetVar game_id $xgame_id

		tpBindString XGAME_STATUS [db_get_col $rs 0 status]

		if {[db_get_col $rs 0 has_balls]=="G"} {
		    tpSetVar showBalls 1
		}

		set sort [db_get_col $rs 0 sort]

		if {$sort=="TOPSPOT"} {
		    tpSetVar showChoosePics 1
		    tpSetVar showAssignArea 1
		    tpSetVar showPositionBalls 1
		}

		if {[db_get_col $rs 0 status]=="S" && ($num_unsettled_bets>0 || $num_bets == 0 || [db_get_col $rs 0 external_settle]=="Y")} {

			set results [db_get_col $rs 0 results]

            if {$sort=="PBUST4" ||
				$sort=="PBUST3" ||
				$sort=="CPBUST3" ||
				$sort=="L400"   ||
				$sort=="L4000"   ||
				$sort=="SATPOOL" ||
				$sort=="VPOOLSM" ||
				$sort=="VPOOLS10" ||
				$sort=="VPOOLS11" ||
				$sort=="LCLOVER3" ||
				$sort=="LCLOVER5" ||
				$sort=="BIGMATCH" ||
				$sort=="MYTH" ||
				$sort=="MONTHPOOL" ||
				$sort=="TOPSPOT" ||
				$sort=="EFINAL4" ||
				$sort=="ESIXSD" ||
				$sort=="EBIGMATCH" ||
				$sort=="PREMIER10" ||
				$sort=="GOALRUSH" ||
				$sort=="PP1IR6" ||
				$sort=="PP1IR7" ||
				$sort=="PP2IR6" ||
				$sort=="PP2IR7" ||
				$sort=="PP3IR6" ||
				$sort=="PP3IR7" ||
				$sort=="PP4IR6" ||
				$sort=="PP4IR7" ||
				$sort=="PP5IR6" ||
				$sort=="PP5IR7" ||
				$sort=="PP1UK6" ||
				$sort=="PP1UK7" ||
				$sort=="PP2UK6" ||
				$sort=="PP2UK7" ||
				$sort=="PP3UK6" ||
				$sort=="PP3UK7" ||
				$sort=="PP4UK6" ||
				$sort=="PP4UK7" ||
				$sort=="PP5UK6" ||
				$sort=="PP5UK7" ||
				$sort=="BSQUK49" ||
				$sort=="BSQUK49B" ||
				$sort=="BSQIR" ||
				$sort=="BSQIRB" ||
				$sort=="BSQSP" ||
				$sort=="BSQSPB" ||
				$sort=="LC6" ||
				$sort=="IR6" ||
				$sort=="IR7" ||
				$sort=="49S" ||
				$sort=="49BS"} {

                    tpSetVar showResults 1
					OT_LogWrite 1 "valid sort = $sort, setting showResults to 1"

					if {[db_get_col $rs 0 results] != ""} {
						tpSetVar deleteResults 1
					}

			} elseif {[OT_CfgGet XGAME_EDIT_RESULTS "0"] == "1"} {

                tpSetVar showResults 1

                if {[db_get_col $rs 0 results] != ""} {
                    tpSetVar deleteResults 1
                }
            }

			if {[db_get_col $rs 0 results] != ""} {
				tpBindString results_string [join [split [db_get_col $rs 0 results] |] ", "]
			} else {
				tpBindString results_string -
			}

			if {$sort=="PBUST4" ||
				$sort=="PBUST3" ||
				$sort=="CPBUST3" ||
				$sort=="SATPOOL" ||
				$sort=="VPOOLSM" ||
				$sort=="VPOOLS10" ||
				$sort=="VPOOLS11" ||
				$sort=="BIGMATCH" ||
				$sort=="MONTHPOOL"} {

				tpSetVar showDividends 1
		    }

		}
		#
		# allow the user to alter dividends for premier10 even
		# if the game is active!!
		#
		if {$sort=="PREMIER10"} {
			tpSetVar showDividends 1
		}

		if {([db_get_col $rs 0 results]!="") && ($num_unsettled_bets > 0)} {
			if {[db_get_col $rs 0 external_settle] == "N"} {
				tpSetVar showSettle 1
			}
		}

        	if {([db_get_col $rs 0 status]=="V") && ($num_unsettled_bets > 0)} {
			tpSetVar showSettle 1
		}

		if {[db_get_col $rs 0 status]=="A"} {
			if {$sort!="BIGMATCH" && $sort!="MYTH" && $sort!="TOPSPOT"} {
				tpSetVar showConvert 1
			}
		}

		tpSetVar honourSubsOnActivate [OT_CfgGet XG_HONOUR_SUBS_ON_ACTIVATE "0"]

		#
		#	Retrieve draw desc details if approp.
		#
		#
		# If make editable only if not yet passed open at time

		if {[OT_CfgGet XG_DYNAMIC_DRAW_DESC "0"] == "1"} {

			tpSetVar currDrawDescId [db_get_col $rs 0 draw_desc_id]

			#
			#	If game open then draw_desc cannot be modified
			#
			if [catch {set rs_g [xg_exec_qry $xgaQry(game_open) $xgame_id]} msg] {
				return [handle_err "game_open" "error: $msg"]
			}

			if {[db_get_nrows $rs_g] == 1} {
				tpSetVar GAME_OPEN 1
			}
			db_close $rs_g

			## more importantly dont modify draw_desc if this game has bets on it
			if {$num_bets> 0} {
				tpSetVar GAME_OPEN 1
			}


			#
			#	Retrieve possible draw descriptions
			#

			if [catch {set rs_draws [xg_exec_qry $xgaQry(game_draw_desc) $sort]} msg] {
				return [handle_err "game_draw_desc" "error: $msg"]
			}

			tpSetVar DRAW_DESC 1
			xg_bind_rs $rs_draws "DRAW"

			# if no rows then error!!!
			db_close $rs_draws

		}

		db_close $rs


	} else {

		tpSetVar opAdd 1

		tpBindString SORT [reqGetArg sort]
		set sort [reqGetArg sort]
		if [catch {set rs [xg_exec_qry $xgaQry(next_comp_no) $sort]} msg] {
	    	return [handle_err "next_comp_no" "error: $msg"]
		}
		set ncn [db_get_col $rs 0 ncn]
		if {$ncn!=""} {
	    	tpBindString COMP_NO $ncn
		} else {
	    	tpBindString COMP_NO 1
		}
		db_close $rs

		if {[OT_CfgGet XG_DYNAMIC_DRAW_DESC "0"] == "1"} {
			#
			#	Retrieve possible draw descriptions
			#
			if [catch {set rs [xg_exec_qry $xgaQry(game_draw_desc) $sort]} msg] {
				return [handle_err "game_draw_desc" "error: $msg"]
			}

			tpSetVar DRAW_DESC 1
			xg_bind_rs $rs "DRAW"

			# if no rows then error!!!
			db_close $rs
		}

    }

    tpSetVar getCalTime 1

    X_play_file editgame.html
}

# this procedure fills my heart with joy
proc H_DoEditGame args {
    global xgaQry CHK_ERR


	if {[reqGetArg do]=="Back"} {
		H_GoXGameFind
		return
	}

	if {[reqGetArg do]=="Edit Selections"} {
		H_GoEditBalls
		return
	}

	if {[reqGetArg do]=="Edit Results"} {
		H_GoEditResults
		return
	}

	if {[reqGetArg do]=="Delete Results"} {
		H_GoDeleteResults [ob_chk::get_arg xgame_id -on_err -1 {UINT}]
		return
	}

	if {[reqGetArg do]=="Edit Dividends"} {
		H_GoEditDividend
		return
	}

	if {[reqGetArg do]=="Settle Bets"} {
		H_GoSettleBets [ob_chk::get_arg xgame_id -on_err -1 {UINT}]
		return
	}

	if {[reqGetArg do]=="Unsettle Bets"} {
		H_GoUnsettleBets [reqGetArg xgame_id]
		return
	}

	if {[reqGetArg do]=="Place Bets from Subscriptions"} {
		process_subs_for_xgame
		return
	}

	if {[reqGetArg do]=="Choose Pictures"} {
		H_GoTopSpotChoosePics
		return
	}

	if {[reqGetArg do]=="Assign Area"} {
		H_GoTopSpotAssignArea
		return
	}

	if {[reqGetArg do]=="Position Balls"} {
		H_GoPlaceBalls
		return
	}
	# CHK_ERR is global
    set CHK_ERR 0

	tpSetVar ignoreFormMessage 1

    comp_field_check "Competition Number" "comp_no"
    comp_field_check "Open at" "open_at"
    comp_field_check "Shut at" "shut_at"
    comp_field_check "Draw at" "draw_at"
    comp_field_check "Status" "status"

	if {[OT_CfgGet XG_DYNAMIC_DRAW_DESC "0"] == "1"} {
		if {[reqGetArg game_open] != "1"} {
			comp_field_check "game draw description" "draw_desc"
		}
	}

	if {$CHK_ERR==1} {
		rebind_and_play "addGame"
		return
	}

	if {[reqGetArg open_at] > [reqGetArg shut_at]} {
		return [handle_err "Constraint violation" "The game shuts before it opens"]
	}

	if {[reqGetArg draw_at] < [reqGetArg shut_at]} {
		return [handle_err "Constraint violation" "The results are known before the game shuts"]
	}

    set xgame_id [reqGetArg xgame_id]

	if {$xgame_id != ""} {
		OT_LogWrite 1 "Modifying external game"
		set qry "xg_exec_qry {$xgaQry(setup_xgame)} \"$xgame_id\""
	} else {
		OT_LogWrite 1 "Adding external game"
		set qry "xg_exec_qry {$xgaQry(add_xgame)}"
	}

	foreach c {sort comp_no open_at shut_at draw_at status desc misc_desc draw_desc} {
		set p [reqGetArg $c]
		if {$c == "xgame_id" && $p==""} {
	    	set p null
		}
		append qry " \"$p\""
	}

	set sort [reqGetArg sort]


	if [catch {set rs [eval $qry]} msg] {
		return [handle_err "setup_xgame/add_xgame" "error: $msg"]
	}

	set new_xgame_id [db_get_coln $rs 0 0]
	db_close $rs


	set status [reqGetArg status]
	set original_status [reqGetArg original_status]

	if {[OT_CfgGet XG_HONOUR_SUBS_ON_ACTIVATE "0"]} {
		##
		## if this game is active
		## first thing to do is to honour any subs which may be stored
		## only do this if the game is being activated or starting of activated
		##
		if {$status == "A" && $status != $original_status} {
			process_subs_for_xgame $new_xgame_id
			tpSetVar tried_to_process_subs 1
		}
	}

	if {[reqGetArg xgame_id]==""} {

		if {$sort=="SATPOOL"
			|| $sort=="MONTHPOOL"
			|| $sort=="MYTH"
			|| $sort=="VPOOLSM"
			|| $sort=="VPOOLS10"
			|| $sort=="VPOOLS11"} {

	    	H_GoEditBalls $new_xgame_id
	    	return
		}

		H_GoEditGame $new_xgame_id
		return
	}

    H_GoEditGame $new_xgame_id
}


#
# Rebind the form variables so we can replay add page
#
proc rebind_and_play {page} {

	# Currently only rebind for the add game
	if {$page == "addGame"} {
		tpSetVar opAdd 1
		tpBindString COMP_NO "[reqGetArg comp_no]"
		tpBindString OPEN_AT "[reqGetArg open_at]"
		tpBindString SHUT_AT "[reqGetArg shut_at]"
		tpBindString DRAW_AT "[reqGetArg draw_at]"
		tpBindString XGAME_STATUS "[reqGetArg status]"
		tpBindString DESC "[reqGetArg desc]"
		tpBindString MISC_DESC "[reqGetArg misc_desc]"
		tpBindString DRAW_DESC "1"
		tpBindString SORT "[reqGetArg sort]"
		tpSetVar SORT "[reqGetArg sort]"
		tpSetVar currDrawDescId "[reqGetArg draw_desc]"

		H_GoEditGame
	}
}

proc show_matching_games args {
    global xgaQry DB
    global GAMES

	catch {unset GAMES}

    set early        [ob_chk::get_arg EarliestDate -on_err "" {RE -args {[A-z0-9\s+-]+}}]
	set late         [ob_chk::get_arg LatestDate -on_err "" {RE -args {[A-z0-9\s+-]+}}]
    set sort         [ob_chk::get_arg sort -on_err "" {ALNUM}]
    set SelectStatus [ob_chk::get_arg SelectStatus -on_err "" {EXACT -args {A S V}}]

	set sql [subst {
		select
			name,
			xgame_id,
			comp_no,
			draw_at,
			status,
			open_at,
			shut_at,
			g.desc
		from
			tXGame g,
			tXGameDef d
		where
			d.sort = g.sort
		and draw_at >= $early
		and open_at <= $late
	}]

	if {$sort == ""} {
		set sort "all"
	}

	if {$sort != "all"} {

		set found [string first "'" $sort]

		ob_log::write INFO {show_matching_games: query - single quote found = $found}

		if {$found > -1} {
			set sort [string replace $sort $found $found "''"]
				ob_log::write INFO {show_matching_games: query -  new sort = $sort}
		}

		set sql "$sql and g.sort = '$sort'"
		tpBindString DESC $sort
	} else {
		tpBindString DESC "All Games"
	}

	if {$SelectStatus != ""} {
		append sql " and status = '$SelectStatus'"
	}

	append sql " order by comp_no"

    set qry [inf_prep_sql $DB $sql]

	if [catch {set rs [inf_exec_stmt $qry]} msg] {
		return [handle_err "get timespan_game_match"\
			"error retrieving timespan_game_match: $msg"]
	}

    set nrows [db_get_nrows $rs]
    tpSetVar nrows $nrows

	if {$nrows > 0} {
		set cols [list comp_no draw_at status open_at shut_at desc name xgame_id]

		# If we are not displaying all games then set the description
		if {$sort != "all"} {
			tpBindString DESC [db_get_col $rs 0 name]
		}

		for {set r 0} {$r < $nrows} {incr r} {

			foreach col $cols {
				set GAMES($r,$col) [db_get_col $rs $r $col]
			}
		}

		foreach col $cols {
			tpBindVar $col GAMES $col idx
		}
	}

	tpBindString EarliestDate $early
	tpBindString LatestDate   $late
	tpBindString sort         $sort
	tpBindString SelectStatus $SelectStatus
	if {[ob_chk::get_arg GameName -on_err "" \
			{EXACT -args {"Update Matching Games"}}] != ""} {
		tpSetVar Update 1
	}

    db_close $rs
    inf_close_stmt $qry

	asPlayFile -nocache "xgame/showmatchinggames.html"
}


proc H_GoEditBalls {{xgame_id ""}} {

    global xgaQry

    if {$xgame_id==""} {
		set xgame_id [ob_chk::get_arg xgame_id_$i -on_err -1 {UINT}]
    }

    if [catch {set rs [xg_exec_qry $xgaQry(game_detail) $xgame_id]} msg] {
		return [handle_err "game_detail"\
					"error: $msg"]
    }

    foreach c {xgame_id num_max sort comp_no draw_at} {
		tpBindString [string toupper $c] [db_get_col $rs 0 $c]
		tpSetVar     [string toupper $c] [db_get_col $rs 0 $c]
    }

    db_close $rs

    if [catch {set rs [xg_exec_qry $xgaQry(get_balls) $xgame_id nosort]} msg] {
		return [handle_err "game_detail"\
					"error: $msg"]
    }

    set nrows [db_get_nrows $rs]
    set nteam 1
    for {set r 0} {$r < $nrows} {incr r} {
		tpSetVar "ballid_[db_get_col $rs $r ball_no]" [db_get_col $rs $r xgame_ball_id]

		if {[tpGetVar SORT]=="SATPOOL" ||
			[tpGetVar SORT]=="MONTHPOOL" ||
			[tpGetVar SORT]=="VPOOLSM" ||
			[tpGetVar SORT]=="VPOOLS10" ||
			[tpGetVar SORT]=="VPOOLS11"} {

			regexp {([^\|]+)\|(.+)} [db_get_col $rs $r ball_name] junk team1 team2

			if {[info exists team1]} {
				tpSetVar "team1_[db_get_col $rs $r ball_no]" $team1
			}
			if {[info exists team2]} {
				tpSetVar "team2_[db_get_col $rs $r ball_no]" $team2
			}
		}

		if {[tpGetVar SORT]=="MYTH"} {
			set teams [split [db_get_col $rs $r ball_name] "|"]

			for {set i 1} {$i <= 4} {incr i} {
				OT_LogWrite 1 [string trim [lindex $teams $i] *]
				OT_LogWrite 1 "team${i}_[db_get_col $rs $r ball_no]"
				tpSetVar "team${i}_[db_get_col $rs $r ball_no]" [string trim [lindex $teams [expr {$i-1}]] *]
				if {[tpGetVar "team${i}_[db_get_col $rs $r ball_no]"]!=[lindex $teams [expr {$i-1}]]} {
					tpSetVar "checked${i}_[db_get_col $rs $r ball_no]" "checked"
				} else {
					tpSetVar "checked${i}_[db_get_col $rs $r ball_no]" ""
				}
			}
		}

		if {[tpGetVar SORT]=="PREMIER10"} {

			set teams [split [db_get_col $rs $r ball_name] "|"]

			set team1 	[lindex $teams 0]
			set team2 	[lindex $teams 1]

			if {![info exists hash($team1,$team2)]} {
				set hash($team1,$team2) [db_get_col $rs $r ball_name]
				tpSetVar team1_${nteam} $team1
				tpSetVar team2_${nteam} $team2
				incr nteam
			}
		}

		if {[tpGetVar SORT] == "GOALRUSH"} {
			set teams [split [db_get_col $rs $r ball_name] "|"]
			tpSetVar team1_${nteam} [lindex $teams 0]
			tpSetVar team2_${nteam} [lindex $teams 1]
			incr nteam
		}
    }
    db_close $rs

    if {[tpGetVar SORT]=="SATPOOL" || [tpGetVar SORT]=="MONTHPOOL" || [tpGetVar SORT]=="VPOOLSM" || [tpGetVar SORT]=="VPOOLS10" || [tpGetVar SORT]=="VPOOLS11"} {
		X_play_file editballspools.html
    }
    if {[tpGetVar SORT]=="MYTH"} {
		X_play_file editballsmyth.html
    }
    if {[tpGetVar SORT]=="PREMIER10"} {
		X_play_file editballspremier10.html
    }
	if {[tpGetVar SORT]=="GOALRUSH"} {
		X_play_file editballsgoalrush.html
	}
}

proc H_DoEditBalls args {

    global xgaQry CHK_ERR DB

    set numballs [reqGetArg NUM_MAX]
    set xgame_id [reqGetArg XGAME_ID]
    set sort     [reqGetArg SORT]

	if {$sort == "PREMIER10"} {
		set numballs	[expr {$numballs * 3}]
	}

    set CHK_ERR 0

    for {set r 1} {$r <= $numballs} {incr r} {
		set name [format_ball $r]
		check_ball_format $sort $r $name
		if {$CHK_ERR != 0} {

			return
		}
    }

    for {set r 1} {$r <= $numballs} {incr r} {
		set name [format_ball $r]
		if {[info exists hash($name)]} {

			if {$sort == "PREMIER10"} {
				# the row number for PREMIER10 is 'special'
				set r [expr {round($r / 3) + 1}]
			}
			handle_err "Duplicate name" "Selection $r has a duplicate name"
			return
		} else {
			set hash($name) 1
		}
    }

    inf_begin_tran $DB

    for {set r 1} {$r <= $numballs} {incr r} {
		set id [reqGetArg "ballid_$r"]
		set name [format_ball $r]
		OT_LogWrite 1 "name = $name; id=$id"
		if {$id==""} {
		    if [catch {xg_exec_qry $xgaQry(insert_ball) $xgame_id $r $name} msg] {
				inf_rollback_tran $DB
				return [handle_err "insert selection number $r" "error: $msg"]
		    }
		} else {
		    if [catch {xg_exec_qry $xgaQry(update_ball) $name $id} msg] {
				inf_rollback_tran $DB
				return [handle_err "update selection number $r" "error: $msg"]
		    }
		}
    }
    inf_commit_tran $DB
    H_GoXGameFind
}

proc H_GoDeleteResults {{xgame_id ""} } {
    global xgaQry


	# call on stored procedure to delete results - checking no bets
	# have been settled using results then return with


    if [catch [xg_exec_qry $xgaQry(delete_results) $xgame_id] msg] {
		return [handle_err "delete_results" "error: $msg"]
    }

    H_GoEditGame $xgame_id

}

proc H_GoEditResults {{xgame_id ""}} {
    global xgaQry

	if {$xgame_id==""} {
		set xgame_id [reqGetArg xgame_id]
	}

    set rs [get_subs_for_game $xgame_id]
    set nrows [db_get_nrows $rs]
    db_close $rs
    if {$nrows != 0} {
		return [handle_err "Outstanding subscription" "You cannot enter results until you have placed the bets for the outstanding subscriptions. Please make the game active again, and click the 'Place Bets from Subscriptions' button."]
    }


	if [catch {set rs [xg_exec_qry $xgaQry(game_detail) $xgame_id]} msg] {
		return [handle_err "game_detail"\
		    "error: $msg"]
	}

	foreach c {xgame_id num_max sort comp_no draw_at num_results_max num_results_min name} {
		tpBindString [string toupper $c] [db_get_col $rs 0 $c]
		tpSetVar     [string toupper $c] [db_get_col $rs 0 $c]
	}

    set has_balls [db_get_col $rs 0 has_balls]
    set results   [db_get_col $rs 0 results]
    set sort      [db_get_col $rs 0 sort]


    db_close $rs

    # Top Spot is a rather special case
    if {$sort=="TOPSPOT"} {
		H_GoTopSpotMark
		return
    }

    # Bind in ball names

	if [catch {set rs [xg_exec_qry $xgaQry(get_balls) $xgame_id $sort]} msg] {
		return [handle_err "game_detail"\
		    "error: $msg"]
	}
    set nrows [db_get_nrows $rs]

    if { $sort=="PBUST4" ||
		$sort=="PBUST3" ||
		$sort=="CPBUST3" ||
		$sort=="L400" ||
		$sort=="SATPOOL" ||
		$sort=="MONTHPOOL" ||
		$sort=="VPOOLSM" ||
		$sort=="VPOOLS10" ||
		$sort=="VPOOLS11" ||
		$sort=="EFINAL4" ||
		$sort=="ESIXSD" ||
		$sort=="IL" ||
	    $sort=="SPL" ||
		$sort=="NYL" ||
		$sort=="SPL7" ||
		$sort=="NYL7"} {

		for {set r 0} {$r < $nrows} {incr r} {
	    	tpSetVar "ballname_[db_get_col $rs $r ball_no]" [db_get_col $rs $r ball_name]
		}

		if {$sort!="SATPOOL" &&
			$sort!="MONTHPOOL" &&
			$sort!="VPOOLSM" &&
			$sort!="VPOOLS10" &&
			$sort!="VPOOLS11" &&
			$sort!="ESIXSD"} {

	    	## if Euro2000 final four, get all those teams which have '*'
	    	if {$sort=="EFINAL4"} {
				set dot ""
				for {set r 0} {$r < $nrows} {incr r} {
		    		set team [db_get_col $rs $r ball_name]
		    		if {[string first "*" $team] != -1} {
						if {[llength $dot] != 0} {
			    			append dot "|"
						}
		        		append dot "[expr {$r+1}]"
		    		}
				}
				tpBindString FINAL4_DOT "<input type=hidden name=efinal4dot value=\"$dot\">"
	    	}

	    	# Check the appropriate boxes
	    	foreach n [split $results "|"] {
				tpSetVar "checked_$n" "checked"
	    	}

		} else {
	    	# Check the appropriate boxes
	    	set type 1
	    	foreach res [split $results "x"] {
				foreach n [split $res "|"] {
		    		tpSetVar "checked_${type}_${n}" "checked"
				}
				incr type
	    	}
		}
    }

	#Paddy Power games
	if {$sort=="PP1IR6" ||
		$sort=="PP2IR6" ||
		$sort=="PP3IR6" ||
		$sort=="PP4IR6" ||
		$sort=="PP5IR6" ||
		$sort=="PP1IR7" ||
		$sort=="PP2IR7" ||
		$sort=="PP3IR7" ||
		$sort=="PP4IR7" ||
		$sort=="PP5IR7" ||
		$sort=="PP1UK6" ||
		$sort=="PP2UK6" ||
		$sort=="PP3UK6" ||
		$sort=="PP4UK6" ||
		$sort=="PP5UK6" ||
		$sort=="PP1UK7" ||
		$sort=="PP2UK7" ||
		$sort=="PP3UK7" ||
		$sort=="PP4UK7" ||
		$sort=="PP5UK7" ||
		$sort=="LC6" ||
		$sort=="IR6" ||
		$sort=="IR7" ||
		$sort=="49S" ||
		$sort=="49BS"} {

		for {set r 0} {$r < $nrows} {incr r} {
	    	tpSetVar "ballname_[db_get_col $rs $r ball_no]" [db_get_col $rs $r ball_name]
		}

		# Check the appropriate boxes
		foreach n [split $results "|"] {
			tpSetVar "checked_$n" "checked"
		}

 	}


	if {$sort=="BSQUK49" ||
		$sort=="BSQUK49B" ||
		$sort=="BSQIR" ||
		$sort=="BSQIRB" ||
		$sort=="BSQSP" ||
		$sort=="BSQSPB"} {

		for {set r 0} {$r < $nrows} {incr r} {
			tpSetVar "ballname_[db_get_col $rs $r ball_no]" [db_get_col $rs $r ball_name]
		}


		#
		# If bonus ball game, need to filter out bonus ball
		#
		if {[HasBonusBall $sort]} {
			tpSetVar BONUS_BALL 1


			set result_list [split $results |]
			set num_results [llength $result_list]

			OT_LogWrite 10 "num_results = $num_results"
			if {$num_results > 0} {
				set bonus [lindex $result_list [expr {$num_results - 1}]]
				set results_minus_bonus [lrange $result_list 0 [expr {$num_results - 2}]]

				# Check the appropriate boxes
				foreach n $results_minus_bonus {
					tpSetVar "checked_$n" "checked"
				}

				foreach b $bonus {
					tpSetVar "checked_bonus_$b" "checked"
				}
			}

		} else {

			# Check the appropriate boxes
			foreach n [split $results "|"] {
				tpSetVar "checked_$n" "checked"
			}
		}

 	}

    if { $sort=="BIGMATCH" || $sort=="EBIGMATCH"} {

		foreach n [split $results "|"] {
	    	set checked_${n} 1
		}
		for {set r 0} {$r < $nrows} {incr r} {
	    	set "ballname_[db_get_col $rs $r ball_no]" [db_get_col $rs $r ball_name]
		}


		set content ""
		for {set r 1} {$r <= 5} {incr r} {
	    	append content "<tr>"
	    	for {set c 1} {$c <= 6} {incr c} {
				append content "<td>"
				append content "<input type=radio name=results_${r} value=$c"
				if {[info exists "checked_${r}${c}"]} {
		    		append content " checked"
				}
				append content ">"
				regexp {(.+:)(.+)} [set ballname_$r$c] junk heading value
				if {$c==1} {
		    		append content $heading
				}
				append content $value
				append content "</input>"
				append content "</td>"
	    	}
	    	append content "</tr>"
		}
		tpBindString CONTENT $content
    }

    if { $sort=="MYTH" } {
		set content ""
		foreach n [split $results "|"] {
	    	set checked_$n 1
		}

		for {set y 1} {$y <= 8} {incr y} {
	    	append content "<tr><td>$y</td>"
	    	for {set x 0} {$x < 4} {incr x} {
				append content "<td><input type=radio name=results_${y} value=$x"
				if [info exists checked_$y$x] {
		    		append content " checked"
				}
				append content ">"
				append content "</td>"
	    	}
	    	append content "</tr>"
		}

		tpBindString CONTENT $content
    }


    if {$sort=="PREMIER10"} {

		set nteam 1
		set balls [split $results "|"]

		set row 1
		foreach n $balls {

			if {$n=="V"} {
				tpSetVar check_${row}_V "checked"
			} else {
				tpSetVar check_$n "checked"
			}

			# increment the row
			incr row
		}

		for {set i 0} {$i < $nrows} {incr i} {

			tpSetVar "ballid_[db_get_col $rs $i ball_no]" [db_get_col $rs $i xgame_ball_id]

			set teams [split [db_get_col $rs $i ball_name] "|"]

			set team1 	[lindex $teams 0]
			set team2 	[lindex $teams 1]

			if {[info exists hash($team1,$team2)]} {
				# this combination has already been added
			} else {

				set hash($team1,$team2) [db_get_col $rs $i ball_name]
				tpSetVar team1_${nteam} $team1
				tpSetVar team2_${nteam} $team2
				incr nteam
			}
		}
    }

	if {$sort == "GOALRUSH"} {
		set balls [split $results "|"]

		foreach ballinfo $balls {
			set ball [string index $ballinfo 0]
			set result [string index $ballinfo 1]

			if {$result == "V"} {
				tpSetVar checkV_${ball} "checked"
			} else {
				tpSetVar check${result}_${ball} "checked"
			}
		}

		for {set index 0} {$index < $nrows} {incr index} {
			set nteam [expr {$index + 1}]
			tpSetVar "ballid_[db_get_col $rs $index ball_no]" [db_get_col $rs $index xgame_ball_id]
			set teams [split [db_get_col $rs $index ball_name] "|"]
			tpSetVar team1_${nteam} [lindex $teams 0]
			tpSetVar team2_${nteam} [lindex $teams 1]
		}
	}

    db_close $rs


    if {$sort=="BIGMATCH" || $sort=="EBIGMATCH"} {
		X_play_file "results_bigmatch.html"
		return
    }

    if {$sort=="MYTH"} {
		X_play_file "results_myth.html"
		return
    }

    if {$sort=="SATPOOL" || $sort=="MONTHPOOL" || $sort=="VPOOLSM" || $sort=="VPOOLS10" || $sort=="VPOOLS11"} {
		X_play_file "results_pools.html"
		return
    }

    if {$sort=="ESIXSD"} {
		X_play_file "results_e2000sixSD.html"
		return
    }

    if {$sort=="PREMIER10"} {
		X_play_file "results_premier10.html"
		return
    }

	if {$sort == "GOALRUSH"} {
		X_play_file "results_goalrush.html"
		return
	}

    X_play_file "results.html"
}

proc H_DoEditResults args {
    global xgaQry

    set sort [reqGetArg SORT]

    set max_type 1
    if {$sort=="MONTHPOOL" ||
		$sort=="SATPOOL" ||
		$sort=="VPOOLSM" ||
		$sort=="VPOOLS10" ||
		$sort=="VPOOLS11"} {
		set max_type 5
    }

    if {$sort=="ESIXSD"} {
		set max_type 3
    }

    # PREMIER10 is a special case
    if {$sort=="PREMIER10"} {
    	set final_answer [H_DoEditResultsPrem10]
    	# check for errors
    	if {$final_answer == ""} {
    		return
    	}
    	set xgame_id [reqGetArgs xgame_id]
    } elseif {$sort == "GOALRUSH"} {
		set nrows [reqGetArgs NUM_RESULTS_MAX]
		set answer {}

		for {set index 1} {$index < 7} {incr index} {
			lappend answer "${index}[reqGetArg result_${index}]"
		}

		set final_answer [join $answer "|"]
    	set xgame_id [reqGetArgs xgame_id]
		OT_LogWrite 1 "final_answer = $final_answer"
	} else {

    	# Multiple types of result for pools games
    	for {set type 1} {$type <= $max_type} {incr type} {
			set results [reqGetArgs results]
			if {$sort=="BIGMATCH" || $sort=="MYTH" || $sort=="EBIGMATCH"} {
				if {$sort=="BIGMATCH" || $sort=="EBIGMATCH"} {
					set howmany 5
				} else {
					set howmany 8
				}
				for {set i 1} {$i <= $howmany} {incr i} {
					if {[reqGetArg "results_$i"]!=""} {
						OT_LogWrite 1 [reqGetArg "results_$i"]
						lappend results "$i[reqGetArg "results_$i"]"
					}
				}
			}

			if {$sort=="MONTHPOOL" ||
				$sort=="SATPOOL" ||
				$sort=="VPOOLSM" ||
				$sort=="VPOOLS10" ||
				$sort=="VPOOLS11" ||
				$sort=="ESIXSD"} {
					set results [reqGetArgs results_${type}]
			}


			set xgame_id [reqGetArgs xgame_id]
			set num_results_max [reqGetArgs NUM_RESULTS_MAX]
			set num_results_min [reqGetArgs NUM_RESULTS_MIN]


			## Check that the correct number or results have been entered
			if {$sort=="BSQUK49B" || $sort=="BSQIRB" || $sort=="BSQSPB"} {


				## Including bonus ball

				set bonus_result [reqGetArgs bonus_result]

				if {![info exists bonus_result]} {
					return [handle_err "No bonus ball selected" "You should select one bonus ball"]
				}

				if {[llength $bonus_result] > 1} {
					return [handle_err "More than one bonus ball selected" "You should select only one bonus ball"]
				}

				if {[lsearch -glob $results $bonus_result] != -1} {
					return [handle_err "Number has been selected in both lists." "Select either as bonus ball or as regular ball."]
				}


				# add bonus ball to end of results

				lappend results $bonus_result

				if {![info exists results] || [llength $results]<$num_results_min || [llength $results]>$num_results_max} {
					return [handle_err "Wrong number of results selected" "You should select between $num_results_min and $num_results_max selections"]
				}


				if {![info exists results] || [llength $results]<$num_results_min || [llength $results]>$num_results_max} {
					return [handle_err "Wrong number of results selected" "You should select between $num_results_min and $num_results_max selections"]
				}
			} else {

				## Check that roughly the right number of selections has been made
				if {![info exists results] || [llength $results]<$num_results_min || [llength $results]>$num_results_max} {
					return [handle_err "Wrong number of results selected" "You should select between $num_results_min and $num_results_max selections"]
				}

			}


			## If a Euro2000 Final Four Game, check that only 2 selections from set marked '*' are present
			if {$sort == "EFINAL4"} {
				set total 0
				set dots [reqGetArgs efinal4dot]
				foreach ball [split $results " "] {
					foreach dball [split $dots "|"] {
						if {$ball == $dball} {
							set total [expr {$total + 1}]
						}
					}
				}

				OT_LogWrite 1 "results=$results dots=$dots total=$total"

				if {$total != 2} {
					return [handle_err "Invalid selections" "Select two teams marked \"* \" and two teams marked without."]
				}
			}

			append final_answer [join $results "|"]
			if {($max_type==5 && $type<"5.0") || ($max_type==3 && $type<"3.0")} {
				append final_answer "x"
			}
    	}
    }

    ## Set the value into the database

    if [catch [xg_exec_qry $xgaQry(update_results) $final_answer $xgame_id] msg] {
		return [handle_err "update_results" "error: $msg"]
    }

    H_GoEditGame
}



#------------------------------------------------------------------------------
# HasBonusBall
#------------------------------------------------------------------------------
#
# args:
#	sort		- db primary key representing type of game
#
# Bonus ball games are represented with a game sort ending with 'b' or 'B'.
#
# returns:
#	1 if game sort is interpreted as having bonus ball,
#	otherwise 0 is returned
#------------------------------------------------------------------------------


proc HasBonusBall {sort} {

	set lastChar [string  index $sort end]

	if {[string equal -nocase $lastChar "b"]} {
		return 1
	} else {
		return 0
	}
}
#end HasBonusBall





proc H_DoEditResultsPrem10 {} {
	global xgaQry

	set nResults	[reqGetArg NUM_MAX]

	for {set i 1} {$i <= $nResults} {incr i} {

		set ball_number [reqGetArg result_${i}]

		if {$ball_number == ""} {
			return [handle_err "No selection" "No selection made for row $i"]
		}

		append result_string $ball_number

		if {$i != $nResults} {
			append result_string "|"
		}
	}
	return $result_string
}

proc handle_err {msg1 msg2} {
	global CHK_ERR ERROUT

	if {![info exists ERROUT] || $ERROUT!="-"} {
		tpBindString MSG1 $msg1
		tpBindString MSG2 $msg2
		set CHK_ERR 1
		X_play_file error.html
	} else {
		puts "Error: $msg1: $msg2"
	}
}

proc handle_success {msg1 msg2} {
	global ERROUT
	if {![info exists ERROUT] || $ERROUT!="-"} {
		tpBindString MSG1 $msg1
		tpBindString MSG2 $msg2
		X_play_file success.html
	} else {
		puts "Success: $msg1: $msg2"
	}
}


proc comp_field_check {description name} {
	if {[reqGetArg $name]==""} {
		handle_err "The following field is compulsory" "$description"
	}
}

proc format_ball {no} {
	if {[reqGetArg SORT]=="SATPOOL" || [reqGetArg SORT]=="MONTHPOOL" || [reqGetArg SORT] == "GOALRUSH" || [reqGetArg SORT] == "VPOOLSM" || [reqGetArg SORT]=="VPOOLS10" || [reqGetArg SORT]=="VPOOLS11"} {
		set res [reqGetArg "team1_$no"]
		append res "|"
		append res [reqGetArg "team2_$no"]
		return $res
	}

	if {[reqGetArg SORT]=="MYTH"} {
		for {set i 1} {$i <=4} {incr i} {
			append res [reqGetArg "team${i}_$no"]
			if {$i=="1" || $i=="2"} {
				set x "12"
			} else {
				set x "34"
			}
			if {[reqGetArg "r${x}_$no"]==$i} {
				append res "*"
			}
			if {$i!="4"} {
				append res "|"
			}
		}
		OT_LogWrite 1 $res
		return $res
	}

	if {[reqGetArg SORT]=="PREMIER10"} {

    	# decode the row number of the match (zero based)
		set row 		[expr {round(($no - 1) / 3)}]

    	# decode the index into the row
		set item		[expr {$no - ($row * 3)}]

    	# now make the row 1 based
		incr row

		set team1 	[reqGetArg team1_$row]
		set team2 	[reqGetArg team2_$row]

		switch -exact -- $item {
			1	{ set result "Home" }
    		2	{ set result "Draw" }
    		3	{ set result "Away" }
		}

		set res [format "%s%s%s%s%s" $team1 "|" $team2 "|" $result]
		return $res
	}
}


proc check_ball_format {sort no name} {

	if {$sort=="SATPOOL" || $sort=="MONTHPOOL" || $sort=="VPOOLSM" || $sort=="VPOOLS10" || $sort=="VPOOLS11"} {
		regexp {([^\|]+)\|(.+)} $name junk team1 team2
		if {![info exists team1] || $team1=="" || ![info exists team2] || $team2==""} {
		    return [handle_err "Team Undefined" "The team names for selection $no should be of the form 'team 1|team 2'"]
		}
	}

	if {$sort=="MYTH"} {
		set teams [split $name "|"]
		if {[llength $teams]!=4} {
			return [handle_err "Wrong number of teams" "You must enter four team names for selection $no"]
		}

		foreach tm $teams {
			if {$tm=="" || $tm=="*"} {
				return [handle_err "Missing team error" "One of the team names has been left blank"]
			}
		}

		# Check that precisely one of the teams is matched with a * to denote home/away team
		if { [string length "[string trim [lindex $teams 0] *][string trim [lindex $teams 1] *]"]
		!= [expr {[string length "[lindex $teams 0][lindex $teams 1]"]-1}] } {
			return [handle_err "Distinguished team error" "Precisely one of the first two teams in selection $no must be checked to indicate that it's the team playing in the mythical match"]
		}

		if { [string length "[string trim [lindex $teams 2] *][string trim [lindex $teams 3] *]"]
		!= [expr {[string length "[lindex $teams 2][lindex $teams 3]"]-1}] } {
			return [handle_err "Distinguished team error" "Precisely one of the second two teams in selection $no must be checked to indicate that it's the team playing in the mythical match"]
		}
	}

	if {$sort=="PREMIER10"} {
		set teams [split $name "|"]

		if {[llength $teams]!=3} {
			return [handle_err "Wrong number of teams" "You must enter two teams for selection $no"]
		}

		if {[string trim [lindex $teams 0]]=="" || [string trim [lindex $teams 1]]==""} {
			return [handle_err "Missing team error" "One of the team names has been left blank"]
		}

		set result [string trim [lindex $teams 2]]
		if {$result != "Home" && $result != "Draw" && $result != "Away"} {
			return [handle_err "Incorrect result error" "The result is incorrect"]
		}
	}

	if {$sort == "GOALRUSH"} {
		set teams [split $name "|"]

		if {[llength $teams] != 2} {
			return [handle_err "Wrong number of teams" "You must enter 2 teams for selection $no"]
		}
	}
}

proc H_GoEditDividend {} {

	global xgaQry
	global DIV_ARR

	catch {unset DIV_ARR}

	set xgame_id [reqGetArg xgame_id]

	if [catch {set rs [xg_exec_qry $xgaQry(get_dividends) $xgame_id]} msg] {
		return [handle_err "get_dividends" "error: $msg"]
	}

	set nrows [db_get_nrows $rs]
	tpSetVar NumDiv $nrows

	for {set r 0} {$r < $nrows} {incr r} {
		set DIV_ARR($r,type)   [db_get_col $rs $r type]
		set DIV_ARR($r,points) [db_get_col $rs $r points]
		set DIV_ARR($r,prizes) [db_get_col $rs $r prizes]
		set DIV_ARR($r,div_id) [db_get_col $rs $r xgame_dividend_id]
    }
    db_close $rs

	tpBindVar DIV_TYPE   DIV_ARR type   div_idx
	tpBindVar DIV_POINTS DIV_ARR points div_idx
	tpBindVar DIV_PRIZES DIV_ARR prizes div_idx
	tpBindVar DIV_ID     DIV_ARR div_id div_idx

	tpBindString XGAME_ID $xgame_id
	tpSetVar SORT [reqGetArg sort]

	X_play_file "dividends.html"

}

proc H_DoAddDividend {} {
	global xgaQry

	set xgame_id [reqGetArg xgame_id]
	set points [reqGetArg points]
	set prizes [reqGetArg prizes]
	set type [reqGetArg type]


	######################################################################################
	# REALLY NASTY PREMIER 10 dividends validation
	if {[reqGetArg sort]=="PREMIER10"} {

		# retrieve the current dividends into an array, recording the greatest number of points (should be 10)
		if [catch {set rs [xg_exec_qry $xgaQry(get_dividends) $xgame_id]} msg] {
			return [handle_err "failed to add dividend" "get_dividends error: $msg"]
		}
		set nrows [db_get_nrows $rs]
		for {set i 0} {$i < $nrows} {incr i} {
			set points2 [db_get_col $rs $i points]
			set div($points2) [db_get_col $rs $i prizes]

		}

		if {[info exists div($points)]} {
			return [handle_err "failed to add dividend" "dividend already exists"]
		}

		# add the new dividend
		set div($points) $prizes

		set div_valid_result [ValidateDividendsPrem10 div [expr {$nrows + 1}] $xgame_id]
		if {$div_valid_result != ""} {

			if {$div_valid_result == "Invalid Points"} {
				set div_valid_result "Points entry is invalid (it must be equal to either the number of matches, or 1 less than the last entry)"
			} elseif {$div_valid_result == "Invalid Prizes"} {
				set div_valid_result "Entry must be less than one with a greater number of points"
			}
			return [handle_err "failed to add dividend" "dividend is invalid: $div_valid_result"]
		}
	}
	######################################################################################

	if [catch [xg_exec_qry $xgaQry(insert_dividend) $xgame_id $points $prizes $type] msg] {
		return [handle_err "insert_dividend" "error: $msg"]
	}

	H_GoEditDividend
}

proc H_DoRemoveDividend {} {
    global xgaQry

    set id 			[reqGetArg id]
	set xgame_id 	[reqGetArg xgame_id]
	set points 		[reqGetArg points]

	######################################################################################
	# REALLY NASTY PREMIER 10 dividends validation
	if {[reqGetArg sort]=="PREMIER10"} {

		# retrieve the current dividends into an array, recording the greatest number of points (should be 10)
		if [catch {set rs [xg_exec_qry $xgaQry(get_dividends) $xgame_id]} msg] {
			return [handle_err "failed to add dividend" "get_dividends error: $msg"]
    	}
    	set nrows [db_get_nrows $rs]
    	for {set i 0} {$i < $nrows} {incr i} {
			set points2 [db_get_col $rs $i points]
			set div($points2) [db_get_col $rs $i prizes]

		}

  		if {![info exists div($points)]} {
  			return [handle_err "failed to find dividend" "dividend doesn't exist!"]
  		}

    	# remove the new dividend
    	unset div($points)

		set div_valid_result [ValidateDividendsPrem10 div [expr {$nrows - 1}] $xgame_id]
    	if {$div_valid_result != ""} {

    		if {$div_valid_result == "Invalid Points"} {
    			set div_valid_result "Can't remove this points entry"
    		}
    		return [handle_err "failed to add dividend" "dividend is invalid: $div_valid_result"]
    	}
	}
	######################################################################################

    if [catch [xg_exec_qry $xgaQry(delete_dividend) $id] msg] {
	return [handle_err "delete_dividend"\
		    "error: $msg"]
    }

	tpSetVar SORT [reqGetArg sort]

    H_GoEditDividend
}


######################################################################################
# WARNING: this validates the dividends for PREMIER10 games only
# ensures that:
# 1) points are assigned from n downwards where n = number of matches
# 2) less points = less prizes
proc ValidateDividendsPrem10 {arr num_entries xgame_id} {

	global xgaQry
	upvar $arr div

	if [catch {set rs [xg_exec_qry $xgaQry(game_detail) $xgame_id]} msg] {
		return "Failed to retrieve game details: $msg"
    }
	set num_matches [db_get_col $rs 0 num_max]

    for {set i $num_matches} {$i >= 0} {incr i -1} {

		if {![info exists div($i)]} {
			if {$num_entries == [expr {$num_matches - $i}]} {
				# this is okay!
				return
			} else {
				return "Invalid Points"
			}
		}
		set j [expr {$i - 1}]
		if {![info exists div($j)]} {
			continue;
		}

		if {$div($i) < $div($j)} {
			return "Invalid Prizes"
		}
	}
}

# This procedure is used to add email info to tCustMail
# Messages are sent to Bluesq's email queue for each customer in tCustMail
# - The Charity changes and the user has outstanding Prizebuster3 subscriptions
# - The customer has only one bet left to be placed from a Prizebuster sub
# - The customer's last bet has just been placed from a Prizebuster sub

proc ins_cust_mail { cust_mail_type cust_id ref_id} {
	global LOGIN_DETAILS BSEL xgaQry

	if [catch {set rs [xg_exec_qry $xgaQry(ins_cust_mail) $cust_mail_type $cust_id $ref_id]} msg] {
		OT_LogWrite 2 "\n****\n**** Unable to insert email:$msg ****\n****"
	}

	set cust_mail_id [db_get_coln $rs 0 0]
	if { $cust_mail_id == -1 } {
		OT_LogWrite 2 "\n****\n**** Failed to create cust_mail - cust_mail_type $cust_mail_type maybe be turned off. ****\n****"
	} else {
		OT_LogWrite 2 "Inserted email $cust_mail_id"
	}
}

proc format_date {dt} {
	global FullMonths
	if [regexp {^(....)-(..)-(..) (..):(..):..$} $dt all y m d hh mm] {
                        set m  [string trimleft $m  0]
                        set d  [string trimleft $d  0]
                        set HH $hh
                        set hh [string trimleft $hh 0]

                        if {$hh >= 12} {
                                set hsfx pm
                                set hh [expr {$hh - 12}]
                                if {$hh == "0"} {
                                        set hh "12"
                                }
                        } else {
                                set hsfx am
                        }

                    if {$hh==""} {
                        # Midnight
                        set hh "12"
                    }
	}
	return "$d[day_sfx $d] of [lindex $FullMonths(en) $m] $y $hh:$mm$hsfx"
}


#
# Get the correct two letter suffix for a month day
#
proc day_sfx day {
        switch -- $day {
                1       -
                21      -
                31      { set sfx st }
                2       -
                22      { set sfx nd }
                3       -
                23      { set sfx rd }
                default { set sfx th }
        }
        return $sfx
}

