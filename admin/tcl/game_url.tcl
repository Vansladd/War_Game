# ==============================================================
# $Id: game_url.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2009 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::GAMEURLS {

asSetAct ADMIN::GAMEURLS::GoGameURLList  [namespace code go_game_url_list]
asSetAct ADMIN::GAMEURLS::GoGameURL      [namespace code go_game_url]
asSetAct ADMIN::GAMEURLS::DoGameURL      [namespace code do_game_url]
asSetAct ADMIN::GAMEURLS::GetGameURL     [namespace code get_game_url]



#
# Prepares and plays the screen for displaying all  game urls
#
proc go_game_url_list args {

	global DB
	global GAMEURLS

	set sql [subst {
		select
			game_code_id,
			game_code,
			name,
			url
		from
			tGameCodeMap
		order by
			game_code asc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set num_games [db_get_nrows $res]
	tpSetVar NumGames $num_games

	for {set row 0} {$row < $num_games} {incr row} {
		set GAMEURLS($row,game_code_id) [db_get_col $res $row game_code_id]
		set GAMEURLS($row,game_code)    [db_get_col $res $row game_code]
		set GAMEURLS($row,name)         [db_get_col $res $row name]
		set GAMEURLS($row,url)          [db_get_col $res $row url]
	}

	tpBindVar GameCodeId GAMEURLS game_code_id game_idx
	tpBindVar GameCode   GAMEURLS game_code    game_idx
	tpBindVar GameName   GAMEURLS name         game_idx
	tpBindVar GameURL    GAMEURLS url          game_idx

	asPlayFile -nocache game_url_list.html

	db_close $res

	catch {unset GAMEURLS}
}



#
# Go to single  game url add/update
#
proc go_game_url args {

	global DB

	set game_code_id [reqGetArg GameCodeId]

	if {$game_code_id == ""} {

		tpSetVar opAdd 1

	} else {
		if {[catch {
			tpSetVar opAdd 0

			# Get game information
			set sql [subst {
				select
					game_code_id,
					game_code,
					name,
					url
				from
					tGameCodeMap
				where
					game_code_id = ?
			}]

			set stmt [inf_prep_sql $DB $sql]
			set res  [inf_exec_stmt $stmt $game_code_id]

			inf_close_stmt $stmt

			if {[db_get_nrows $res] != 1} {
				err_bind "Unable to find URL for $game_code"
			}

			tpBindString GameCodeId [db_get_col $res 0 game_code_id]
			tpBindString GameCode   [db_get_col $res 0 game_code]
			tpBindString GameName   [db_get_col $res 0 name]
			tpBindString GameURL    [db_get_col $res 0 url]

			db_close $res

		} msg]} {

			ob_log::write ERROR {game_url::go_game_url: Error retrieving $game_code}
			err_bind "Unable to retrieve information for $game_code - $msg"
			go_game_url_list
			return

		}

	}

	asPlayFile -nocache game_url.html
}



#
# Wrapper for choosing which action to take
#
proc do_game_url args {

	set act [reqGetArg SubmitName]

	if {$act == "Add"} {
		do_game_url_add
	} elseif {$act == "Mod"} {
		do_game_url_upd
	} elseif {$act == "Del"} {
		do_game_url_del
	} elseif {$act == "Back"} {
		go_game_url_list
		return
	} else {
		error "unexpected SubmitName: $act"
	}

}



#
# Adds a new  game url to tGameCodeMap
#
proc do_game_url_add args {

	global DB

	set sql [subst {
		execute procedure pInsGameCodeMap (
			p_game_code = ?,
			p_name = ?,
			p_url = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	set game_code [reqGetArg GameCode]
	set game_name [reqGetArg GameName]
	set game_url  [reqGetArg GameURL]

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$game_code\
			$game_name\
			$game_url]} msg]} {
		ob_log::write ERROR {game_url::do_game_url_add: Error inserting \
									game $game_code with URL: $game_url}
		err_bind "Unable to add new game $game_code - $msg"
		set bad 1
	}

	inf_close_stmt $stmt


	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
	} else {
		reqSetArg GameCodeId [db_get_coln $res 0 0]
		catch {db_close $res}
	}

	tpSetVar GameURLAdded 1

	go_game_url

}



#
# Updates a  game url in tGameCodeMap
#
proc do_game_url_upd args {

	global DB

	set sql [subst {
		update
			tGameCodeMap
		set
			game_code = ?,
			name    = ?,
			url     = ?
		where
			game_code_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	set game_code_id [reqGetArg GameCodeId]
	set game_code [reqGetArg GameCode]
	set game_name [reqGetArg GameName]
	set game_url  [reqGetArg GameURL]

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$game_code\
			$game_name\
			$game_url\
			$game_code_id]} msg]} {
		ob_log::write ERROR {game_url::do_game_url_upd: Error updating \
			game $game_code with name: $game_name, and URL: $game_url}
		err_bind "Unable to update game $game_code - $msg"
		set bad 1
	}

	inf_close_stmt $stmt
	catch {db_close $res}

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
	}

	tpSetVar GameURLUpdated 1
	go_game_url

}



#
# Deletes a  game url from tGameCodeMap
#
proc do_game_url_del args {

	global DB

	set sql [subst {
		delete from
			tGameCodeMap
		where
			game_code_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	set game_code_id [reqGetArg GameCodeId]
	set game_code [reqGetArg GameCode]

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$game_code_id]} msg]} {
		ob_log::write ERROR {game_url::do_game_url_upd: Error deleting\
				game $game_code}
		err_bind "Unable to delete game $game_code - $msg"
		set bad 1
	}

	inf_close_stmt $stmt
	catch {db_close $res}

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_game_url
		return
	}

	tpSetVar GameURLDeleted 1
	tpBindString deletedCode [reqGetArg GameCode]

	go_game_url_list

}

}
