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
    asSetAct WAR_GAME_Lobbies_JSON          [namespace code get_lobbies_json]

    proc get_lobbies_json args {
        puts "--------------------------------> GETTING JSON LOBBIES"
        global DB
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

        puts "----------------------------------> $json"

        tpBindString JSON $json
        
        puts "-----------------------------------> Play JSON TEMPLATE"
        asPlayFile -nocache war_games/jsonTemplate.json
        
    }

    proc go_login_page args {
        asPlayFile -nocache war_games/login.html
    }

    proc do_login_page args {
        set username [reqGetArg username]
        puts "================================$username"

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
        puts "----------------------------------------> FOUND $user_id"

        puts "--------------------------------> GOING TO LOBBY PAGE"
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

        return user_id
    }

    proc create_user {username} {
        global DB
        puts "---------------------------------> username = $username"
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
        puts "------------------> ENTERING LOBBY PAGE"
        asPlayFile -nocache war_games/lobby_page.html
    }

    proc go_room_page args {
        asPlayFile -nocache war_games/waiting_room.html
    }

    proc go_game_page args {
        asPlayFile -nocache game_page.html
    }
    
}