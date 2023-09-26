# ==============================================================
# File path
# ~/git_src/induction/training/admin/tcl/war_games/war_game.tcl
# ==============================================================

namespace eval WAR_GAME {

	asSetAct WAR_GAME_Login                 [namespace code go_login_page]
    asSetAct WAR_GAME_Do_Login              [namespace code do_login_page]
    asSetAct WAR_GAME_Lobby                 [namespace code go_lobby_page]
    asSetAct WAR_GAME_Game                  [namespace code go_game_page]
    asSetAct WAR_GAME_Waiting_Room          [namespace code go_room_page]
    asSetAct WAR_GAME_Join_Game             [namespace code go_join_game]

    asSetAct WAR_GAME_Lobbies_JSON          [namespace code get_lobbies_json]
    asSetAct WAR_GAME_Waiting_Room_JSON     [namespace code get_waiting_room_json]

    proc get_waiting_room_json args {
        global DB

        set room_id [reqGetArg room_id]

        set sql {
            select 
                player1_id,
                player2_id
            from
                tactivewarroom
            where
                room_id = ?
        }

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt $room_id]} msg]} {
			tpBindString err_msg "error occured while executing query"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby.html
			return
		}

        catch {inf_close_stmt $stmt}

        set player1_id [db_get_col $rs 0 player1_id]
        set player2_id [db_get_col $rs 0 player2_id]

        db_close $rs

        set json "\{\"player2_id\": \"$player2_id\", \"room_id\":$room_id, \"player1_id\": \"$player1_id\"\}"
        
        tpBindString JSON $json

        asPlayFile -nocache war_games/jsonTemplate.json

    }

    proc go_join_game args {
        global DB

        # Note: this is currently hard coded. Please change when possible
        set player1_id [reqGetArg player1_id]
        set player2_id [reqGetArg player2_id]
        set room_id    [reqGetArg room_id]
        set user_id    [reqGetArg user_id]

        # Done to prevent two queries from loading at once
        if {$user_id == $player2_id} {
            set sql {
                INSERT INTO twargame (cr_date)
                VALUES (CURRENT YEAR TO SECOND);
            }

            if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
                tpBindString err_msg "error occured while preparing statement"
                ob::log::write ERROR {===>error: $msg}
                tpSetVar err 1
                asPlayFile -nocache war_games/lobby.html
                return
            }
            
            if {[catch {set rs [inf_exec_stmt $stmt]} msg]} {
                tpBindString err_msg "error occured while executing query"
                ob::log::write ERROR {===>error: $msg}
                catch {inf_close_stmt $stmt}
                tpSetVar err 1
                asPlayFile -nocache war_games/lobby.html
                return
            }
        }

        # Send to HTML page
        asPlayFile -nocache game_page.html
    }

    proc get_lobbies_json args {
        global DB
        # change sql select statement
        set sql {
            select
                *
            from 
                tactivewarroom;
        }

         if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt]} msg]} {
			tpBindString err_msg "error occured while executing query"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby.html
			return
		}

        catch {inf_close_stmt $stmt}

        set num_rooms [db_get_nrows $rs]
		tpSetVar num_rooms $num_rooms
	
        set roomid ""
        set user ""

		for {set i 0} {$i < $num_rooms} {incr i} {
            if {$i == 0} {
            set roomid "$roomid[db_get_col $rs $i room_id]"
			#set ROOM($i,room_id)   [db_get_col $rs $i room_id]

            if {[db_get_col $rs $i player1_id] == ""} {
                set user "$user ''"
            } else {
                set user "$user[db_get_col $rs $i player1_id]"
            }
			#set ROOM($i,player_1)  [db_get_col $rs $i player_1]
            } else {

                if {[db_get_col $rs $i player1_id] == ""} {
                    set user "$user,''"
                } else {
                    set user "$user,[db_get_col $rs $i player1_id]"
                }
                set roomid "$roomid,[db_get_col $rs $i room_id]"
                #set user "$user,[db_get_col $rs $i player1_id]"
            }
        }
        set user "\[$user\]"
        set roomid "\[$roomid\]"
        db_close $rs
		
		set json "
            \{ \"roomid\": $roomid , \"starting_money\": \[50,78\] , \"user\": $user \}
        "

        tpBindString JSON $json
        
        asPlayFile -nocache war_games/jsonTemplate.json
        
    }

    proc go_login_page args {
        asPlayFile -nocache war_games/login.html
    }

    proc do_login_page args {
        set username [reqGetArg username]

        global DB

        # SQL Query Code here
        set sql {
            SELECT 
                COUNT(*) AS username_exists
            FROM 
                twaruser
            WHERE 
                username = ?;
        }

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt $username]} msg]} {
			tpBindString err_msg "error occured while executing query"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}

        set user_exists [db_get_col $rs 0 username_exists]

        catch {db_close $rs}

        if {$user_exists == 0} {
            create_user $username
        } 

        set user_id [get_user_id $username]
        tpBindString user_id $user_id

        # If statement to different pages
        go_lobby_page 
    }

    proc get_user_id {username} {
        global DB

        set sql {
            select 
                user_id
            from
                twaruser
            where
                username = ?;
        }

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt $username]} msg]} {
			tpBindString err_msg "error occured while executing query"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}

        set user_id [db_get_col $rs 0 user_id]
        catch {db_close $rs}

        return $user_id
    }

    proc create_user {username} {
        global DB
        # SQL Query Code here
        set sql {
            INSERT INTO twaruser (username, acct_bal)
            VALUES (?, 1000);
        }

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error1: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}
		
		if {[catch {inf_exec_stmt $stmt $username} msg]} {
			tpBindString err_msg "error occured while executing query"
			ob::log::write ERROR {===>error2: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}
    }
    
    proc go_lobby_page args {
        asPlayFile -nocache war_games/lobby_page.html
    }

    # Rename for similar naming
    proc go_room_page args {
        global DB

        set user_id [reqGetArg user_id]
        set room_id [reqGetArg room_id]

        # Need to make an if statement to update either player1 or player2 depending on number of players

        # SQL query to update tactiveroom
        set sql {
            update 
                tactivewarroom
            set 
                player2_id = ?
            where 
                room_id = ?
        }

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby.html
			return
		}
		
		if {[catch {inf_exec_stmt $stmt $user_id $room_id} msg]} {
			tpBindString err_msg "error occured while executing query"
			ob::log::write ERROR {===>error2: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby.html
			return
		}

        catch {inf_close_stmt $stmt}

        tpBindString user_id $user_id
        tpBindString room_id $room_id

        asPlayFile -nocache war_games/waiting_room.html
    }

    proc go_game_page args {
        asPlayFile -nocache game_page.html
    }
    
}