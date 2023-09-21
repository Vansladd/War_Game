# ==============================================================
# $Id: games.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2002 Orbis Technology Ltd. All rights reserved.
# ==============================================================


namespace eval ADMIN::GAMES {

	asSetAct ADMIN::GAMES::GoGameSetup [namespace code go_game_setup]
	asSetAct ADMIN::GAMES::GoGame      [namespace code go_game]
	asSetAct ADMIN::GAMES::UpdateGame  [namespace code go_update_game]
	asSetAct ADMIN::GAMES::AddGame     [namespace code go_add_game]


	proc go_game_setup {} {

		global DB

		set sql [subst {
			select
			*
			from
			tGameDef
		}]


		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		tpSetVar NumGames [db_get_nrows $res]

		tpBindTcl GAME_ID    sb_res_data $res game_idx game_id
		tpBindTcl GAME_NAME  sb_res_data $res game_idx name
		tpBindTcl GAME_URL   sb_res_data $res game_idx link
		tpBindTcl GAME_POPUP sb_res_data $res game_idx popup
		tpBindTcl GAME_HORIZ sb_res_data $res game_idx horiz
		tpBindTcl GAME_VERT  sb_res_data $res game_idx vert

		asPlayFile -nocache game_list.html

		db_close $res
	}


	proc  go_game {} {

		global DB

		set sql [subst {
			select
			*
			from
			tGameDef
			where game_id = ?
		}]


		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt [reqGetArg GameId]]
		OT_LogWrite 1 "Game_id = [reqGetArg GameId]"

		inf_close_stmt $stmt

		OT_LogWrite 1 "ROWS: [db_get_nrows $res]"

		tpBindString GAME_ID     [db_get_col $res 0 game_id]
		tpBindString GAME_NAME   [db_get_col $res 0 name]
		tpBindString GAME_BLURB  [db_get_col $res 0 blurb]
		tpBindString GAME_BLURB2 [db_get_col $res 0 blurb2]
		tpBindString GAME_URL    [db_get_col $res 0 link]
		tpBindString GAME_POPUP  [db_get_col $res 0 popup]
		tpBindString GAME_HORIZ  [db_get_col $res 0 horiz]
		tpBindString GAME_VERT   [db_get_col $res 0 vert]

		asPlayFile -nocache game_detail.html

		db_close $res
	}

	proc go_update_game {} {
		switch [reqGetArg SubmitName] {
			"Add"    do_add_game
			"Update" update_game
			"Delete" delete_game
		}
	}



	proc update_game {} {

		global DB

		set sql [subst {
			update
				 tGameDef
			set
				  name = ?,
				  blurb = ?,
				  blurb2 = ?,
				  link = ?,
				  popup = ?,
				  horiz = ?,
				  vert = ?
			where
				  game_id = ?
		}]

		set stmt [inf_prep_sql $DB $sql]

		set game_id     [reqGetArg GameId]
		set name        [reqGetArg GameName]
		set whole_blurb [reqGetArg GameBlurb]
		set blurb       [string range $whole_blurb 0 254]
		set blurb2      [string range $whole_blurb 255 511]
		set url         [reqGetArg GameURL]
		set popup       [reqGetArg GamePopup]
		set horiz       [reqGetArg GameHoriz]
		set vert        [reqGetArg GameVert]

		OT_LogWrite 1 "Updating game: $game_id"

		if {$popup=="Y"} {
			inf_exec_stmt $stmt $name $blurb $blurb2 $url $popup $horiz $vert $game_id
		} else {
			inf_exec_stmt $stmt $name $blurb $blurb2 $url $popup "" "" $game_id
		}

		msg_bind "Game $name successfully updated"
		go_game
	}


	proc delete_game {} {

		global DB

		set sql [subst {
			delete from
				tGameDef
			where
				game_id = ?
		}]

		set stmt [inf_prep_sql $DB $sql]

		inf_exec_stmt $stmt [reqGetArg GameId]

		go_game_setup
	}

	proc go_add_game {} {
		tpSetVar operation "Add"
		asPlayFile -nocache game_detail.html
	}

	proc do_add_game {} {
		global DB

		set sql [subst {
			insert into tGameDef (
			   	name,
				blurb,
				link,
				popup,
				horiz,
				vert
				)
			values (
				?,?,?,?,?,?
				)
		}]

		set stmt [inf_prep_sql $DB $sql]

		set game_id  [reqGetArg   GameId]
		set name     [reqGetArg   GameName]
		set blurb    [reqGetArg   GameBlurb]
		set url      [reqGetArg   GameURL]
		set popup    [reqGetArg   GamePopup]
		set horiz    [reqGetArg   GameHoriz]
		set vert     [reqGetArg   GameVert]

		if {$popup=="Y"} {
			inf_exec_stmt $stmt $name $blurb $url $popup $horiz $vert
		} else {
			inf_exec_stmt $stmt $name $blurb $url $popup "" ""
		}

		go_game_setup
	}

}