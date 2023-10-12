# ==============================================================vewaruser
# File path
# ~/git_src/induction/training/admin/tcl/war_games/war_game.tcl
# ==============================================================
            
namespace eval WAR_GAME {

	asSetAct WAR_GAME_Login                 [namespace code go_login_page]
    asSetAct WAR_GAME_Do_Login              [namespace code do_login]
    asSetAct WAR_GAME_Do_Signup             [namespace code do_signup]
    asSetAct WAR_GAME_Lobby                 [namespace code go_lobby_page]
    asSetAct WAR_GAME_Game                  [namespace code go_game_page]
    asSetAct WAR_GAME_Waiting_Room          [namespace code go_room_page]
    asSetAct WAR_GAME_LOGOUT                [namespace code do_logout]
    asSetAct WAR_GAME_Join_Game             [namespace code go_join_game]
    asSetAct WAR_GAME_Leave_Room            [namespace code leave_room]
    asSetAct WAR_GAME_Flip_card             [namespace code flip_card]
    asSetAct WAR_GAME_Leave_Waiting_Room    [namespace code leave_waiting_room]

    asSetAct WAR_GAME_Inital_bet            [namespace code initial_bet]
    asSetAct WAR_GAME_Forfeit               [namespace code forfeit]

    asSetAct WAR_GAME_User_JSON             [namespace code get_user_json]
    asSetAct WAR_GAME_Lobbies_JSON          [namespace code get_lobbies_json]
    asSetAct WAR_GAME_Waiting_Room_JSON     [namespace code get_waiting_room_json]
    asSetAct WAR_GAME_game_state_JSON       [namespace code game_state_json]

    proc get_active_user {user_id} {
        global DB

        set sql {
            SELECT 
                sess_id
            FROM
                tactivewaruser
            where
                user_id = ?
        }

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt $user_id]} msg]} {
			tpBindString err_msg "error occured while executing query"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}

        set sess_id ""
        if {[db_get_nrows $rs] > 0} {
            set sess_id [db_get_col $rs 0 sess_id]
        }

        catch {db_close $rs}

        return $sess_id
    }

    proc update_last_active {user_id} {
        global DB

        set sql {
            UPDATE
                tactivewaruser
            SET
                last_active = dbinfo('utc_current')
            WHERE
                user_id = ?
        }

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}
		
		if {[catch [inf_exec_stmt $stmt $user_id] msg]} {
			tpBindString err_msg "error occured while executing query"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}
    }

    proc disconnect_timeout_users args {

        global DB
        global SESSION

        set sql {
            select 
                sess_id, user_id, room_id
            from 
                tactivewaruser
            where
                dbinfo('utc_current') - last_active > 600;
        }


        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt]} msg]} {
			tpBindString err_msg "error occured while executing query"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}

        set num_users [db_get_nrows $rs]

        # Note - refactor to ensure setplayerid and only change which player gets the thing and return the result
        for {set i 0} {$i < $num_users} {incr i} {
            set SESSION($i,sess_id) [db_get_col $rs $i sess_id]
            set SESSION($i,user_id) [db_get_col $rs $i user_id]
            set SESSION($i,room_id) [db_get_col $rs $i room_id]
        }

        disconnect_users_in_games $num_users
        disconnect_users_in_room  $num_users
        disconnect_active_users   $num_users
        
        catch {unset $SESSION}
        db_close $rs
    }

    proc disconnect_users_in_room {num_users} {
        global SESSION 
        global DB
        if {$num_users <= 0} {return}

        set where "room_id = $SESSION(0,room_id)"

        for {set i 1} {$i < $num_users} {incr i} {
            set where "$where OR room_id = $SESSION($i,room_id)"            
        }

        set sql [subst {
            update 
                tactivewaruser
            set
                room_id = NULL
            where 
                $where  
        }]

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}
		
		if {[catch [inf_exec_stmt $stmt] msg]} {
			tpBindString err_msg "error occured while executing query"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}
    }

    proc disconnect_active_users {num_users} {
        # Disconnect users from tactivewarusers
        global SESSION
        global DB
        if {$num_users <= 0} {return}

        set where "sess_id = $SESSION(0,sess_id)"

        for {set i 1} {$i < $num_users} {incr i} {
            set where "$where OR sess_id = $SESSION($i,sess_id)"            
        }

        set sql [subst {
            delete from 
                tactivewaruser
            where 
                $where  
        }]

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}
		
		if {[catch [inf_exec_stmt $stmt] msg]} {
			tpBindString err_msg "error occured while executing query"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}
    }

    # NOTE: NOT DONE YET AS WE HAVE YET TO COMPLETE GAMES
    proc disconnect_users_in_games {num_users} {
        # Insert disconnect user from game logic here (To be completed later)
        global DB
        global SESSION
        
        if {$num_users <= 0} {return}

        set user_id_list $SESSION(0,user_id)

        for {set i 1} {$i < $num_users} {incr i} {
            set user_id_list "$user_id_list, $SESSION($i,user_id)"
        }

        set sql [subst {
            SELECT DISTINCT
                tu.room_id,
                tr.game_id,
                CASE 
                    WHEN tu2.user_id IN ($user_id_list) THEN tu.user_id
                    ELSE tu2.user_id
                END AS other_player_user_id
            FROM
                tactivewaruser tu
            INNER JOIN
                tactivewarroom tr
                ON tu.room_id = tr.room_id
            LEFT JOIN
                tactivewaruser tu2
                ON tu.room_id = tu2.room_id
                AND tu.user_id != tu2.user_id
            WHERE
                tu.user_id IN ($user_id_list) OR tu2.user_id IN ($user_id_list);
        }]

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt]} msg]} {
			tpBindString err_msg "error occured while executing query"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}

        for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
            update_win_game [db_get_col $rs $i game_id] [db_get_col $rs $i other_player_user_id] DISCONNECT 
        }

        catch {db_close $rs}
    }

    proc forfeit args {
        global DB

        set user_id [reqGetArg user_id]
        set room_id [reqGetArg room_id]
        set game_id [room_id_to_game_id $room_id]

        update_last_active $user_id

        # Check if someone has forfeited by hacking into link?
        set ret_players [get_user_id_in_room $room_id]

        set PLAYERS(player1_id)     [lindex $ret_players 0]
        set PLAYERS(player2_id)     [lindex $ret_players 1]

        if {$PLAYERS(player1_id) == $user_id} {
            set winner $PLAYERS(player2_id)
        } elseif {$PLAYERS(player2_id) == $user_id} {
            set winner $PLAYERS(player1_id)
        } else {
            # Error message (user isn't in the room, which means they are not actively playing)
        }

        update_win_game $game_id $winner FORFEIT
    }

    proc update_win_game {game_id winner_id win_condition} {
        global DB

        set sql [subst {
            UPDATE 
                twargame
            SET 
                winner_id = ?,
                win_condition_id = (
                    SELECT 
                        win_condition_id
                    FROM 
                        twarwincondition
                    WHERE 
                        win_condition = '$win_condition'
                )
            WHERE 
                game_id = ?;
        }]

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

		if {[catch {inf_exec_stmt $stmt $winner_id $game_id} msg]} {
			tpBindString err_msg "Please enter a non-empty username!"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}
    }

    proc do_logout args {
        global DB

        set user_id [reqGetArg user_id]

        set sql {
            DELETE FROM tactivewaruser
            where user_id = ?
        }


        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt $user_id]} msg]} {
			tpBindString err_msg "Please enter a non-empty username!"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}

        catch {db_close $rs}

        go_login_page

    }

    proc get_username {user_id} {
        global DB

        set sql {
            select
                username
            From
                twaruser
            where
                user_id = ?
        }


        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt $user_id]} msg]} {
			tpBindString err_msg "Please enter a non-empty username!"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}

        
        set user_name [db_get_col $rs 0 username]

        catch {db_close $rs}

        return $user_name

    }



    proc get_user_balance {user_id} {
        global DB

        set sql {
            select
                acct_bal
            From
                twaruser
            where
                user_id = ?


        }


        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt $user_id]} msg]} {
			tpBindString err_msg "Please enter a non-empty username!"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}

        
        set user_bal [db_get_col $rs 0 acct_bal]

        catch {db_close $rs}
        return $user_bal
    }

    proc end_game_update_user_balance {user_id room_id} {
        global DB

        set game_id [room_id_to_game_id $room_id]
        set current_turn [get_turn_number $game_id ]
        set move_id [get_moves_id $game_id $user_id $current_turn]

        set acct_bal [get_user_balance $user_id]

        set game_bal [game_balance $user_id $room_id]

        set starting_bal [get_starting_money $room_id]

        set difference_bal [expr $game_bal - $starting_bal]

        set new_balance [expr $acct_bal + $difference_bal]

        set sql {
            update twaruser
            SET
                acct_bal = ?
            where
                user_id = ?


        }


        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}
		
		if {[catch {inf_exec_stmt $stmt $new_balance $user_id} msg]} {
			tpBindString err_msg "Please enter a non-empty username!"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}

    }

    proc get_starting_money {room_id} {
        global DB

        set sql {
            select
                starting_money
            From
                tactivewarroom
            where
                room_id = ?


        }


        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt $room_id]} msg]} {
			tpBindString err_msg "Please enter a non-empty username!"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}

        
        set starting_money [db_get_col $rs 0 starting_money]

        catch {db_close $rs}
        return $starting_money
    }



    proc start_game_update_user_balance {user_id room_id} {
        global DB

        set game_id [room_id_to_game_id $room_id]

        set acct_bal [get_user_balance $user_id]

        set game_bal [get_starting_money $room_id]

        set new_balance [expr $acct_bal - $game_bal]

        set sql {
            update twaruser
            SET
                acct_bal = ?
            where
                user_id = ?
        }


        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}
		
		if {[catch {inf_exec_stmt $stmt $new_balance $user_id} msg]} {
			tpBindString err_msg "Please enter a non-empty username!"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}
    }

    proc do_signup args {
        set username [reqGetArg username]
        create_user $username
        set user_id [get_user_id $username]

        set_active_session $user_id

        tpBindString user_id $user_id
        set user_balance [get_user_balance $user_id]
        set username [get_username $user_id]

        tpBindString user_balance $user_balance
        tpBindString username $username
        asPlayFile -nocache war_games/lobby_page.html
    }

    proc game_balance {user_id room_id} {
        global DB

        set game_id [room_id_to_game_id $room_id]
        set current_turn [get_turn_number $game_id]
        set move_id [get_moves_id $game_id $user_id $current_turn]

        set sql {
            select
                game_bal
            From
                twargamemoves
            where
                move_id = ?
        }

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt $move_id]} msg]} {
			tpBindString err_msg "Please enter a non-empty username!"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}

        set game_bal [db_get_col $rs 0 game_bal]

        catch {db_close $rs}
        return $game_bal
    }

    proc get_latest_bet {move_id} {
        global DB

        set sql {
            select First 1
                bet_value
            From
                twarbetmove
            where
                move_id = ?
            ORDER BY
                bet_id DESC;
        }


        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt $move_id]} msg]} {
			tpBindString err_msg "Please enter a non-empty username!"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}

        set bet_value ""

        if {[db_get_nrows $rs] > 0} {
            set bet_value [db_get_col $rs 0 bet_value]
        }

        catch {db_close $rs}
        return $bet_value
    }

    proc get_moves_id {game_id user_id turn_number} {
        global DB

        set sql {
            SELECT
                twargamemoves.move_id as move_id
            FROM
                twargamemoves,
                thand
            WHERE
                twargamemoves.game_id = ? AND
                twargamemoves.turn_number = ? AND
                twargamemoves.hand_id = thand.hand_id AND
                thand.player_id = ?
        }


        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}
        
		
		if {[catch {set rs [inf_exec_stmt $stmt $game_id $turn_number $user_id]} msg]} {
			tpBindString err_msg "Please enter a non-empty username!"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}

        set moves_id [db_get_col $rs 0 move_id]

        catch {db_close $rs}
        return $moves_id
    }
    
    proc get_user_bet {move_id} {
        set bet_id [get_bet_id $move_id]
        return [get_bet_value $bet_id]
    }

    proc get_bet_value {bet_id} {
        global DB


        set sql {
            SELECT
                bet_value
            FROM
                twarbetmove
            WHERE
                bet_id = ?
        }


        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt $bet_id]} msg]} {
			tpBindString err_msg "Please enter a non-empty username!"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}

        
        set bet_value [db_get_col $rs 0 bet_value]

        catch {db_close $rs}
        return $bet_value
    }

    proc get_bet_id {move_id} {
        global DB


        set sql {
            SELECT
                twarbetmove.bet_id as bet_id
            FROM
                twarbetmove,
                twargamemoves
            WHERE
                twarbetmove.move_id = ? AND
                twarbetmove.move_id = twargamemoves.move_id
        }


        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt $move_id]} msg]} {
			tpBindString err_msg "Please enter a non-empty username!"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}

        
        set bet_id [db_get_col $rs 0 bet_id]

        catch {db_close $rs}
        return $bet_id
    }

    proc to_action_id {bet_action} {
        global DB

        set bet_action $bet_action

        set sql {
            SELECT
                action_id
            FROM
                twarbetactions
            WHERE
                action = ?
        }

        # return json response 
        # who_betted, how much value the bet was, action, 


        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt $bet_action]} msg]} {
			tpBindString err_msg "Please enter a non-empty username!"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}

        set action_id [db_get_col $rs 0 action_id]

        catch {db_close $rs}

        return $action_id
    }

    proc new_turn {game_id loser_id winner_id room_id bet_val} {
        set loser_current_turn [get_turn_number $game_id]
        set winner_current_turn [get_turn_number $game_id]

        set loser_move_id [get_moves_id $game_id $loser_id $loser_current_turn]
        set loser_balance [game_balance $loser_id $room_id]

        array set loser_hand [get_entire_hand $loser_id $loser_move_id]

        set loser_hand_length [expr [array size loser_hand] / 3]


        set winner_move_id [get_moves_id $game_id $winner_id $winner_current_turn]
        set winner_balance [game_balance $winner_id $room_id]
        array set winner_hand [get_entire_hand $winner_id $winner_move_id]
        set winner_hand_length [expr [array size winner_hand] / 3]

        set loser_card_id [get_turned_card $loser_id $game_id $loser_current_turn]

        #determine if this is a sub_round

        set total_hand_length [expr $loser_hand_length + $winner_hand_length]

        if {$total_hand_length == 10} {
            set prev_winner_move_id ""
            set prev_loser_move_id ""

            set prev_loser_hand(0,card_id) ""
            set prev_winner_hand(0,card_id) ""

            set prev_winner_hand_length ""
            set prev_loser_hand_length ""

            set prev_total_hand_length ""

            set back_step 1
            while {1 == 1} {
                set prev_winner_move_id [get_moves_id $game_id $winner_id [expr $winner_current_turn - $back_step]]
                set prev_loser_move_id [get_moves_id $game_id $loser_id [expr $loser_current_turn - $back_step]]

                array set prev_loser_hand [get_entire_hand $loser_id $prev_loser_move_id]
                array set prev_winner_hand [get_entire_hand $winner_id $prev_winner_move_id]

                set prev_loser_hand_length [expr [array size prev_loser_hand] / 3]
                set prev_winner_hand_length [expr [array size prev_winner_hand] / 3]

                set prev_total_hand_length [expr $prev_loser_hand_length + $prev_winner_hand_length]

                if {$prev_total_hand_length == 10} {
                    set back_step [expr $back_step + 1]
                } else {
                    break
                }
            }

            set bet_val [get_latest_bet $prev_winner_move_id]
            if {$bet_val == ""} {
                set bet_val [get_latest_bet $prev_loser_move_id]
            }

            #reshuffling the winner
            set winner_hand_compatible(0) ""
            for {set i 0} {$i < $prev_winner_hand_length} {incr i} {
                set winner_hand_compatible($i) $prev_winner_hand($i,card_id)
            }

            for {set i 0} {$i < 5} {incr i} {
                set winner_hand_compatible([expr $prev_winner_hand_length + $i]) $loser_hand($i,card_id)
            }

            #randomises the deck
            for {set i 0} {$i < [array size winner_hand_compatible]} {incr i} {
                set temp $winner_hand_compatible($i)
                set rand [random_number 0 [expr [array size winner_hand_compatible] - 1]]
                set winner_hand_compatible($i) $winner_hand_compatible($rand)
                set winner_hand_compatible($rand) $temp
            }

            #reshuffling the loser
            set deleted_card 0
            for {set i 0} {$i < [expr $prev_loser_hand_length - 6]} {incr i} {
                for {set j 0} {$j < 5} {incr j} {
                    if {$prev_loser_hand($i,card_id) == $loser_hand($j,card_id)} {
                        set deleted_card [expr $deleted_card + 1]
                    }
                }
                set $prev_loser_hand($i,card_id) $prev_loser_hand([expr $i + $deleted_card],card_id)
            }

            set loser_hand_compatible(0) ""

            for {set i 0} {$i < [expr $prev_loser_hand_length - 5]} {incr i} {
                set loser_hand_compatible($i) $prev_loser_hand($i,card_id)
            }

            #randomises the deck
            for {set i 0} {$i < [array size loser_hand_compatible]} {incr i} {
                set temp $loser_hand_compatible($i)
                set rand [random_number 0 [expr [array size loser_hand_compatible] - 1]]
                set loser_hand_compatible($i) $loser_hand_compatible($rand)
                set loser_hand_compatible($rand) $temp
            }

        } else {
            #winner gains losers chosen card
            set winner_hand($winner_hand_length,card_id) $loser_card_id
            set winner_hand($winner_hand_length,hand_card_id) ""
            set winner_hand($winner_hand_length,hand_id) ""


            set loc_found 0
            #takes a card away from loser (has duplicate at the end)
            for {set i 0} {$i < [expr [expr [array size loser_hand] / 3] - 1]} {incr i} {
                if {$loser_hand($i,card_id) == $loser_card_id} {
                    set loc_found 1
                }
                if {$loc_found == 1} {
                    if {$loser_hand($i,card_id) == $loser_card_id} {
                    }
                    set loser_hand($i,card_id) $loser_hand([expr $i + 1],card_id) 
                }
            }

            array set loser_hand_compatible {}
            array set winner_hand_compatible {}

            #makes hand compatible with function
            for {set i 0} {$i < [expr [expr [array size loser_hand] / 3] - 1]} {incr i} {
                set loser_hand_compatible($i) $loser_hand($i,card_id)
            }


            #randomises the deck of cards for current user
            for {set i 0} {$i < [array size loser_hand_compatible]} {incr i} {
                set temp $loser_hand_compatible($i)
                set rand [random_number 0 [expr [array size loser_hand_compatible] - 1]]
                set loser_hand_compatible($i) $loser_hand_compatible($rand)
                set loser_hand_compatible($rand) $temp
            }

            #makes hand compatible with function
            for {set i 0} {$i < [expr [array size winner_hand] / 3]} {incr i} {
                set winner_hand_compatible($i) $winner_hand($i,card_id)
            }

            #randomises the deck of cards for the winner user
            for {set i 0} {$i < [array size winner_hand_compatible]} {incr i} {
                set temp $winner_hand_compatible($i)
                set rand [random_number 0 [expr [array size winner_hand_compatible] - 1]]
                set winner_hand_compatible($i) $winner_hand_compatible($rand)
                set winner_hand_compatible($rand) $temp
            }

        }
        set loser_hand_id [insert_hand $loser_id $game_id [array get loser_hand_compatible] [array size loser_hand_compatible] [expr $loser_current_turn + 1]]
        set winner_hand_id [insert_hand $winner_id $game_id [array get winner_hand_compatible] [array size winner_hand_compatible] [expr $winner_current_turn + 1]]

        #game_id hand_id turn_number game_bal card_id Final_bet_id

        set loser_move_id [insert_game_moves $game_id $loser_hand_id [expr $loser_current_turn + 1] [expr $loser_balance - $bet_val] "" 0]
        set winner_move_id [insert_game_moves $game_id $winner_hand_id [expr $winner_current_turn + 1] [expr $winner_balance + $bet_val] "" 0]

        create_final_bet $game_id [expr $winner_current_turn + 1]
    }

    proc create_final_bet {game_id turn_number} {
        global DB

        set sql {
            INSERT INTO 
                twarbetfinal (game_id, turn_number)
            VALUES 
                (?, ?)
        }

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}
		
		if {[catch {inf_exec_stmt $stmt $game_id $turn_number} msg]} {
			tpBindString err_msg "Please enter a non-empty username!"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}
    }

    proc get_final_bet_id {game_id turn_number} {
        global DB

        set sql {
            SELECT
                final_bet_id
            FROM
                twarbetfinal
            WHERE
                game_id = ? AND
                turn_number = ?
        }

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt $game_id $turn_number]} msg]} {
			tpBindString err_msg "Please enter a non-empty username!"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}

        set final_bet_id ""

        if {[db_get_nrows $rs]} {
            set final_bet_id [db_get_col $rs 0 final_bet_id]
        }

        catch {db_close $rs}

        return $final_bet_id
    }

    proc get_bet_turn {final_bet_id} {
        global DB

        set sql {
            SELECT
                count(final_bet_id) AS bet_turn
            FROM
                twarbetmove
            WHERE
                final_bet_id = ?
        }

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt $final_bet_id]} msg]} {
			tpBindString err_msg "Please enter a non-empty username!"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}

        set bet_turn [db_get_col $rs 0 bet_turn]

        catch {db_close $rs}

        return $bet_turn
    }

    proc is_room {room_id game_id} {
        #return 0 for game_id no longer in room
        #return 1 for game_id still in room

        set test_game_id [room_id_to_game_id $room_id]

        if {$test_game_id == $game_id} {
            return 1
        } else {
            return 0
        }
    }


    proc wipe_room {room_id} {
        global DB

        global DB

        set sql {
            UPDATE tactivewarroom
            SET game_id = ""
            where
                room_id = ?


        }


        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}
		
		if {[catch {inf_exec_stmt $stmt $room_id} msg]} {
			tpBindString err_msg "Please enter a non-empty username!"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}
    }

    proc end_game {current_user_id other_user_id room_id game_id current_turn} {
    
        set room [is_room $room_id $game_id]

        set user_card_amount [get_card_amount $game_id $other_user_id $current_turn]

        set other_card_amount [get_card_amount $game_id $other_user_id $current_turn]
        set this_balance [game_balance $current_user_id $room_id]

        set other_balance [game_balance $other_user_id $room_id]

        end_game_update_user_balance $current_user_id $room_id
        end_game_update_user_balance $other_user_id $room_id
        if {$room == 1} {
            wipe_room $room_id
        }
    }

    proc sub_round_create {game_id other_user_id current_user_id turn_number room_id} {

        set move_id [get_moves_id $game_id $current_user_id $turn_number]
        array set user_hand [get_entire_hand $current_user_id $move_id]
        set card_amount [get_card_amount $game_id $current_user_id $turn_number]
        set balance [game_balance $current_user_id $room_id]

        set other_move_id [get_moves_id $game_id $other_user_id $turn_number]
        array set other_user_hand [get_entire_hand $other_user_id $other_move_id]
        set other_card_amount [get_card_amount $game_id $other_user_id $turn_number]
        set other_balance [game_balance $other_user_id $room_id]

        set cards(0) ""

        if {$card_amount < 5} {
            return $current_user_id
        } elseif {$other_card_amount < 5} {
            return $other_user_id
        } else {

            #doing cards for current user            
            set new_cards_amount 0

            #getting deck of 5 cards
            while {1 == 1} {
                if {$new_cards_amount >= 5} {
                    break
                }
                set random_number [random_number 0 [expr $card_amount - 1]]
                if {$new_cards_amount == 0} {
                    set cards($new_cards_amount) $user_hand($random_number,card_id)
                    set new_cards_amount [expr $new_cards_amount + 1]
                } else {
                    set is_in_array 0
                    for {set i 0} {$i < $new_cards_amount} {incr i} {
                        if {$user_hand($random_number,card_id) == $cards($i)} {
                            set is_in_array 1
                            break
                        }
                    }
                    if {$is_in_array == 0} {
                        set cards($new_cards_amount) $user_hand($random_number,card_id)
                        set new_cards_amount [expr $new_cards_amount + 1]
                    }
                }
            }


            set new_hand_id [insert_hand $current_user_id $game_id [array get cards] [array size cards] [expr $turn_number + 1]]
            set new_move_id [insert_game_moves $game_id $new_hand_id [expr $turn_number + 1] $balance "" 0]

            #doing cards for other user
            set new_cards_amount 0
            set other_cards(0) ""

            #getting deck of 5 cards
            while {1 == 1} {
                if {$new_cards_amount >= 5} {
                    break
                }
                set random_number [random_number 0 [expr $other_card_amount - 1]]
                if {$new_cards_amount == 0} {
                    set other_cards($new_cards_amount) $other_user_hand($random_number,card_id)
                    set new_cards_amount [expr $new_cards_amount + 1]
                } else {
                    set is_in_array 0
                    for {set i 0} {$i < $new_cards_amount} {incr i} {
                        if {$other_user_hand($random_number,card_id) == $other_cards($i)} {
                            set is_in_array 1
                            break
                        }
                    }
                    if {$is_in_array == 0} {
                        set other_cards($new_cards_amount) $other_user_hand($random_number,card_id)
                        set new_cards_amount [expr $new_cards_amount + 1]
                    }
                }
            }

            set new_hand_id [insert_hand $other_user_id $game_id [array get other_cards] [array size other_cards] [expr $turn_number + 1]]

            set new_move_id [insert_game_moves $game_id $new_hand_id [expr $turn_number + 1] $other_balance "" 0]

        }
        create_final_bet $game_id [expr $turn_number + 1]
        return -1
    }

    proc display_error_message {error_message} {
        set json "
            \{\"error\" : \"$error_message\"\}
        "   
        tpBindString JSON $json

        ob::log::write ERROR {===>$error_message}
        asPlayFile -nocache war_games/jsonTemplate.json
    }

    proc initial_bet args {
        global DB

        set bet             [reqGetArg bet_value]
        set action          [reqGetArg bet_action]
        set room_id         [reqGetArg room_id]
        set user_id         [reqGetArg user_id]
        set game_id         [reqGetArg game_id]
        set turn_number     [get_turn_number $game_id]
        set move_id         [get_moves_id $game_id $user_id $turn_number]
        set final_bet_id    [get_final_bet_id $game_id $turn_number]
        set bet_turn        [get_bet_turn $final_bet_id]

        tpBindString room_id $room_id
        tpBindString user_id $user_id
        tpBindString game_id $game_id

        update_last_active $user_id

        if {$bet != ""} {
            set bet [expr {double(round(100*$bet))/100}]
        }

        set action_id ""

        puts "---------------------------------> $action"

        if {$action == "null"} {
            display_error_message "You need to select your action first for bet!"
            return
        } else {
            set action_id       [to_action_id $action]
        }
        set do_database 0

        set ret_players     [get_user_id_in_room $room_id]

        set PLAYERS(player1_id)     [lindex $ret_players 0]
        set PLAYERS(player2_id)     [lindex $ret_players 1]

        set other_user_id {}
        set current_user_id $user_id
        
        if {$PLAYERS(player1_id) == $user_id} {
            set other_user_id $PLAYERS(player2_id)
            set player_bet_turn 0
        } elseif {$PLAYERS(player2_id) == $user_id} {
            set player_bet_turn 1
            set other_user_id $PLAYERS(player1_id)
        } else {
            return
        }        

        set user_move_id [get_moves_id $game_id $user_id $turn_number]
        set current_user_card_id [get_turned_card $user_id $game_id $turn_number]

        set other_user_move_id [get_moves_id $game_id $other_user_id $turn_number]
        set other_user_card_id [get_turned_card $other_user_id $game_id $turn_number]

        set other_card_amount [get_card_amount $game_id $other_user_id $turn_number]
        set current_card_amount [get_card_amount $game_id $current_user_id $turn_number]
        set total_cards [expr $other_card_amount + $current_card_amount]


        if {$current_user_card_id == ""} {
            display_error_message "You need to select your card first!"
            return
        }

        if {$bet <= 0 && $action == "BET"} {
            display_error_message "Your bet needs be to the nearest pence and above 0!"
            return
        }

        set other_bet_value [get_latest_bet $other_user_move_id]

        if {$other_bet_value == "" && $action == "MATCH"} {
            display_error_message "You need to place a bet first!"
            return
        }

        if {$bet == "" && $action == "BET"} {
            display_error_message "You need to place a bet first!"
            return
        }

        if {$bet != "" && $action == "BET" && $bet <= $other_bet_value} {
            display_error_message "You need to place a higher bet!"
            return
        }

        # Alternate turns so players take turn taking the first bet
        if {[expr $turn_number % 2] == 1} {
            set player_bet_turn [expr 1 - $player_bet_turn]
        } 

        if {[expr $bet_turn % 2] == $player_bet_turn} {
            display_error_message "It is the opponent's turn to make a bet!"
            return
        }


        if {$action == "FOLD" && $total_cards != 5} {
            set current_user_id $user_id

            set current_bet_value [get_latest_bet $user_move_id]
            if {$current_bet_value == ""} {
                set current_bet_value 0
            }
            
            new_turn $game_id $current_user_id $other_user_id $room_id $current_bet_value

            set bet $current_bet_value
            set do_database 1

        } elseif {$action == "MATCH" && $total_cards != 5} {
            set current_user_id $user_id

            array set current_user_card_attributes [get_specific_card $current_user_card_id]
            array set other_user_card_attributes [get_specific_card $other_user_card_id]

            set loser_id ""
            set winner_id ""

            set draw 0

            if {$current_user_card_attributes(0,card_value) > $other_user_card_attributes(0,card_value)} {
                set winner_id $current_user_id
                set loser_id $other_user_id
            } elseif {$current_user_card_attributes(0,card_value) < $other_user_card_attributes(0,card_value)} {
                set loser_id $current_user_id
                set winner_id $other_user_id
            } else {
                #does stuff
                # get loser and winner from tie but with 10 cards 

                set loser_id [sub_round_create $game_id $other_user_id $current_user_id $turn_number $room_id]
                set bet_val [get_latest_bet $other_user_move_id]

                if {$loser_id != -1} {
                    if {$loser_id == $current_user_id} {
                        set winner_id $other_user_id
                    } else {
                        set winner_id $current_user_id
                    }
                    new_turn $game_id $loser_id $winner_id $room_id $bet_val
                }
                set bet $bet_val
                set draw 1
                set do_database 1

                #5 cards from user deck in a sub round
                #do that on its own (might not be difficult just inefficient)

                #sub round (some indication that its a sub round) probably be the total cards in play being 10
                #with that indicated to get back original hand turn_number - 1
            }

            if {$draw == 0} {
                set loser_move_id [get_moves_id $game_id $loser_id $turn_number]
                set winner_move_id [get_moves_id $game_id $winner_id $turn_number]

                set winner_bet_value [get_latest_bet $winner_move_id]
                if {$winner_bet_value == ""} {
                    set winner_bet_value 0
                }

                set loser_bet_value [get_latest_bet $loser_move_id]
                if {$loser_bet_value == ""} {
                    set loser_bet_value 0
                }

                set bet_val $loser_bet_value

                if {$loser_bet_value < $winner_bet_value} {
                    set bet_val $winner_bet_value
                }

                set winner_balance [game_balance $winner_id $room_id]
                set loser_balance [game_balance $loser_id $room_id]

                if {$bet_val <= $loser_balance && $bet_val <= $winner_balance} {
                    set do_database 1
                    new_turn $game_id $loser_id $winner_id $room_id $bet_val
                    set bet $bet_val
                }
            }

        } elseif {$action == "BET" && $total_cards != 5} {

            set current_user_id $user_id

            set last_user_bet [get_latest_bet $user_move_id]
            if {$last_user_bet == ""} {
                set last_user_bet 0
            }

            set last_other_user_bet [get_latest_bet $other_user_move_id]

            if {$last_other_user_bet == ""} {
                set last_other_user_bet 0
            }

            set user_balance [game_balance $current_user_id $room_id]
            set other_balance [game_balance $other_user_id $room_id]

            if {$bet > $user_balance} {
                display_error_message "Cannot bet more money than what you have!"
                return
            }

            if {$bet > $other_balance} {
                display_error_message "Cannot bet more money than what the opponent has!"
                return
            }

            if {$last_user_bet < $bet && $last_other_user_bet < $bet && $user_balance >= $bet && $other_balance >= $bet} {
                set do_database 1
            } 
        }

        if {$do_database == 1} {
            set sql {
                INSERT INTO
                    twarbetmove (bet_value, action_id, move_id, final_bet_id)
                VALUES
                    (?, ?, ?, ?);
            }

            if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
                tpBindString err_msg "error occured while preparing statement"
                ob::log::write ERROR {===>error: $msg}
                tpSetVar err 1
                asPlayFile -nocache war_games/login.html
                return
            }
                
            if {[catch [inf_exec_stmt $stmt $bet $action_id $move_id $final_bet_id] msg]} {
                tpBindString err_msg "error occured while executing query"
                ob::log::write ERROR {===>error: $msg}
                catch {inf_close_stmt $stmt}
                tpSetVar err 1
                asPlayFile -nocache war_games/login.html
                return
            }

            catch {inf_close_stmt $stmt}
        }
        display_error_message ""
        # go_game_page
    }

    proc search_active_session {user_id} {
        global DB

        set sql {
            SELECT 
                sess_id
            FROM
                tactivewaruser
            WHERE 
                user_id = ?
        }

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        if {[catch {set rs [inf_exec_stmt $stmt $user_id]} msg]} {
			tpBindString err_msg "error occured while executing query"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}

        set sess_id ""

        if {[db_get_nrows $rs] > 0} {
            set sess_id [db_get_col $rs 0 sess_id]
        }

        catch {db_close $rs}

        return $sess_id
    }

    proc set_active_session {user_id} {
        global DB

        set sql {
            INSERT INTO 
                tactivewaruser (user_id, last_active)
            VALUES 
                (?, dbinfo('utc_current'));
        }

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}
		
		if {[catch [inf_exec_stmt $stmt $user_id] msg]} {
			tpBindString err_msg "error occured while executing query"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}
    }

    proc do_login args {
        global DB

        set user_id [reqGetArg user_id]
        set sess_id [search_active_session $user_id]

        if {$sess_id != ""} {
            tpBindString err_msg "Cannot login to currently logged in user!"
			ob::log::write ERROR {===>error: $user_id already exists!}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
            return
        }

        set_active_session $user_id 

        tpBindString user_id $user_id 
        set user_balance [get_user_balance $user_id]
        set username [get_username $user_id]

        tpBindString user_balance $user_balance
        tpBindString username $username
        asPlayFile -nocache war_games/lobby_page.html
    }

    proc get_turned_card {user_id game_id current_turn} {
        global DB

       set sql {
            SELECT
                game_moves.card_id as card_id
            FROM
                twargamemoves as game_moves,
                thand as hand
            WHERE
                hand.player_id = ? AND
                hand.hand_id = game_moves.hand_id AND
                game_moves.game_id = ? AND
                game_moves.turn_number = ?
        }

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby_page.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt $user_id $game_id $current_turn]} msg]} {
			tpBindString err_msg "error occured while executing query"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby_page.html
			return
		}


        catch {inf_close_stmt $stmt}

        set card_id ""
        if {[db_get_nrows $rs] > 0} {
            set card_id [db_get_col $rs 0 card_id]
        }

        db_close $rs

        return $card_id

    }
    
    proc get_entire_hand {user_id move_id} {
       global DB
        
        #getting entire hand of player
       set sql {
            SELECT 
                card.card_id as card_id,
                hand_card.hand_card_id as hand_card_id,
                thand.hand_id as hand_id
            FROM
                thand_card as hand_card,
                thand,
                twarcard as card,
                twargamemoves as game_moves
            WHERE
                thand.hand_id = hand_card.hand_id AND
                hand_card.card_id = card.card_id AND
                thand.player_id = ? AND
                game_moves.hand_id = thand.hand_id AND
                game_moves.move_id = ?
            ORDER BY
                hand_card_id ASC
        }

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby_page.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt $user_id $move_id]} msg]} {
			tpBindString err_msg "error occured while executing query"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby_page.html
			return
		} 

        catch {inf_close_stmt $stmt}


        for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
            set HAND($i,card_id) [db_get_col $rs $i card_id]
            set HAND($i,hand_card_id) [db_get_col $rs $i hand_card_id]
            set HAND($i,hand_id) [db_get_col $rs $i hand_id]
        }
        db_close $rs

        return [array get HAND]
    }
    
    
    proc get_specific_card {specific_card_id} {
        global DB

        global CARD

        #getting specific card attributes
        set sql {
            SELECT 
                card.card_value as card_value,
                suit.suit_name as suit_name,
                card.card_name as card_name
            FROM
                twarcard as card,
                tsuit as suit
            WHERE
                suit.suit_id = card.suit_id AND
                card.card_id = ?
        }

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby_page.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt $specific_card_id]} msg]} {
			tpBindString err_msg "error occured while executing query"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby_page.html
			return
		}

        catch {inf_close_stmt $stmt}

        if {[db_get_nrows $rs] > 0} {
            set CARD(0,card_value) [db_get_col $rs 0  card_value]
            set CARD(0,suit_name) [db_get_col $rs 0 suit_name]
            set CARD(0,card_name) [db_get_col $rs 0 card_name]
        } else {
            set CARD(0,card_value) ""
            set CARD(0,suit_name) ""
            set CARD(0,card_name) ""
        }

        db_close $rs

        return [array get CARD]

    }

    proc flip_card args {
        global DB

        set user_id             [reqGetArg user_id]
        set room_id             [reqGetArg room_id]
        set card_location       [reqGetArg card_location]
        set game_id             [reqGetArg game_id]
        set turn_number         [get_turn_number $game_id]
        set move_id             [get_moves_id $game_id $user_id $turn_number]

        update_last_active $user_id

        # Don't flip card if already chosen
        if {[get_turned_card $user_id $game_id $turn_number] != ""} {
            return
        }

        #getting users entire hand
        array set entire_hand [get_entire_hand $user_id $move_id]

        #get users chosen card
        set specific_card_id $entire_hand($card_location,card_id)

        #getting specific card attributes
        array set specific_card [get_specific_card $specific_card_id]

        #getting the number of turns the user did
        set turn_number $turn_number

        set game_bal 50
        set final_bet_id -1

        #inserting change in database
        insert_game_moves $game_id $entire_hand(0,hand_id) $turn_number $game_bal $specific_card_id $final_bet_id

        #where mini turn ends

        set current_user_id $user_id
        set other_user_id {}
        set ret_players [get_user_id_in_room $room_id]

        set PLAYERS(player1_id) [lindex $ret_players 0]
        set PLAYERS(player2_id) [lindex $ret_players 1]

        if {$PLAYERS(player1_id) == $user_id} {
            set other_user_id $PLAYERS(player2_id)
        } elseif {$PLAYERS(player2_id) == $user_id} {
            set other_user_id $PLAYERS(player1_id)
        } else {
            return
        }

        #incase in sub game
        set other_card_id [get_turned_card $other_user_id $game_id $turn_number]

        set other_card_amount [get_card_amount $game_id $other_user_id $turn_number]
        set current_card_amount [get_card_amount $game_id $current_user_id $turn_number]
        if {$other_card_id != "" && [expr $other_card_amount + $current_card_amount] == 10} {
            array set other_specific_card [get_specific_card $other_card_id]

            if {$other_specific_card(0,card_value) > $specific_card(0,card_value)} {
                new_turn $game_id $current_user_id $other_user_id $room_id 0
            } elseif {$other_specific_card(0,card_value) < $specific_card(0,card_value)} {
                new_turn $game_id $other_user_id $current_user_id $room_id 0
            } else {
                sub_round_create $game_id $other_user_id $current_user_id $turn_number $room_id
                
            }
        }

        #go to game page again
        tpBindString room_id $room_id
        tpBindString user_id $user_id
        tpBindString game_id $game_id

        go_game_page
    }

    proc random_number {min max} {
        #generates random number between max and min
        return [expr int((rand() * ($max + 1 - $min)) + $min)]
    }

    proc insert_game_moves {game_id hand_id turn_number game_bal card_id Final_bet_id} {
        global DB

        #inserts the moves that the player makes

        set insert ""
        set values ""
        if {$card_id == ""} {
            set insert "game_id, hand_id, turn_number, game_bal"
            set values "?, ?, ?, ?"

            set sql "
                INSERT INTO twargamemoves ($insert)
                VALUES ($values);
            "

            if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
                tpBindString err_msg "error occured while preparing statement"
                ob::log::write ERROR {===>error: $msg}
                tpSetVar err 1
                asPlayFile -nocache war_games/lobby_page.html
                return
            }
                
            if {[catch {inf_exec_stmt $stmt $game_id $hand_id $turn_number $game_bal $card_id $Final_bet_id} msg]} {
                tpBindString err_msg "error occured while executing query"
                ob::log::write ERROR {===>error: $msg}
                catch {inf_close_stmt $stmt}
                tpSetVar err 1
                asPlayFile -nocache war_games/lobby_page.html
                return
            }

            catch {inf_close_stmt $stmt}
        } else {
            set sql "
                    Update twargamemoves
                    set card_id = ?,
                    Final_bet_id = ?
                    where
                    game_id = ? AND
                    hand_id = ? AND
                    turn_number = ?
            "

            if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
                tpBindString err_msg "error occured while preparing statement"
                ob::log::write ERROR {===>error: $msg}
                tpSetVar err 1
                asPlayFile -nocache war_games/lobby_page.html
                return
            }
                
            if {[catch {inf_exec_stmt $stmt $card_id $Final_bet_id $game_id $hand_id $turn_number} msg]} {
                tpBindString err_msg "error occured while executing query"
                ob::log::write ERROR {===>error: $msg}
                catch {inf_close_stmt $stmt}
                tpSetVar err 1
                asPlayFile -nocache war_games/lobby_page.html
                return
            }

            catch {inf_close_stmt $stmt}
        }

            return [last_pk]
    }

    proc insert_hand {player_id game_id cards card_number turn_number} {
        global DB

        array set CARDS $cards

        #player now has a hand
        set sql {
            INSERT INTO thand (player_id)
            VALUES (?);
        }
            

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
            tpBindString err_msg "error occured while preparing statement"
            ob::log::write ERROR {===>error: $msg}
            tpSetVar err 1
            asPlayFile -nocache war_games/lobby_page.html
            return
        }
            
        if {[catch {inf_exec_stmt $stmt $player_id} msg]} {
            tpBindString err_msg "error occured while executing query"
            ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
            tpSetVar err 1
            asPlayFile -nocache war_games/lobby_page.html
            return
        }

        catch {inf_close_stmt $stmt}

        set hand_id [last_pk]

        for {set i 0} {$i < $card_number} {incr i} {
            #inserts a each card in the hand
            set sql {
                INSERT INTO thand_card (hand_id, turn_number, card_id)
                VALUES (?, ?, ?);
            }
                

            if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
                tpBindString err_msg "error occured while preparing statement"
                ob::log::write ERROR {===>error: $msg}
                tpSetVar err 1
                asPlayFile -nocache war_games/lobby_page.html
                return
            }
                
            if {[catch {inf_exec_stmt $stmt $hand_id $turn_number $CARDS($i)} msg]} {
                tpBindString err_msg "error occured while executing query"
                ob::log::write ERROR {===>error: $msg}
                catch {inf_close_stmt $stmt}
                tpSetVar err 1
                asPlayFile -nocache war_games/lobby_page.html
                return
            }

            catch {inf_close_stmt $stmt}

        }

        return $hand_id

    }

    proc initial_card_assigner {player1_id player2_id game_id room_id} {
        global DB

        global MOVE_ID
        set each_player_card_number 26

        set card_number [expr $each_player_card_number * 2]

        set CARDS(0) ""

        #makes an entire deck of cards
        for {set i 0} {$i < [expr $card_number]} {incr i} {
            set CARDS($i) [expr $i + 1]
        }

        #randomises the deck of cards
        for {set i 0} {$i < [expr $card_number]} {incr i} {
            set temp $CARDS($i)
            set rand [random_number 0 [expr ($each_player_card_number * 2) - 1]]
            set CARDS($i) $CARDS($rand)
            set CARDS($rand) $temp

        }

        set player1_cards(0) ""
        set player2_cards(0) ""

        #assigns each player their own card
        for {set i 0} {$i < $card_number} {incr i} {
            if {$i < $each_player_card_number} {
                set player1_cards($i) $CARDS($i)
            } else {
                set offset [expr $i - $each_player_card_number]
                set player2_cards($offset) $CARDS($i)
            }
        }

        #records the cards for each player in the database        
        set pl1_hand_id [insert_hand $player1_id $game_id [array get player1_cards] $each_player_card_number 0]
        set pl2_hand_id [insert_hand $player2_id $game_id [array get player2_cards] $each_player_card_number 0]

        set p1_bal [get_starting_money $room_id]
        set p2_bal [get_starting_money $room_id]

        set MOVE_ID(0) ""
        
        set MOVE_ID(0,move_id) [insert_game_moves $game_id $pl1_hand_id 0 $p1_bal "" ""]
        set MOVE_ID(1,move_id) [insert_game_moves $game_id $pl2_hand_id 0 $p2_bal "" ""]

        return [array get MOVE_ID]
    }

    proc last_pk {} {
        global DB
        set sql {SELECT DBINFO( 'sqlca.sqlerrd1' ) AS pk
                FROM systables
                WHERE tabid = 1;
        }

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby_page.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt]} msg]} {
			tpBindString err_msg "error occured while executing query"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby_page.html
			return
		}

        catch {inf_close_stmt $stmt}

        set pk [db_get_col $rs 0 pk]

        db_close $rs


        return $pk
    }

    proc room_id_to_game_id {room_id} {
        global DB

        set sql {
            select 
                game_id
            from
                tactivewarroom
            where
                room_id = ?
        }

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby_page.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt $room_id]} msg]} {
			tpBindString err_msg "error occured while executing query"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby_page.html
			return
		}

        catch {inf_close_stmt $stmt}


        set game_id [db_get_col $rs 0 game_id]

        db_close $rs

        return $game_id

    }

    proc get_first_user_bet_id {move_id} {
        global DB

        set sql {
            SELECT
                MIN(twarbetmove.bet_id) as bet_id
            FROM
                twarbetmove,
                twargamemoves
            WHERE
                twargamemoves.move_id = ?
                twargamemoves.move_id = twarbetmove.move_id
            
        }


        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby_page.html
			return
		}
		if {[catch {set rs [inf_exec_stmt $stmt $move_id]} msg]} {
			tpBindString err_msg "error occured while executing query"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby_page.html
			return
		}

        catch {inf_close_stmt $stmt}

        set bet_id ""

        if {[db_get_nrows $rs] != 0} {
            set bet_id [db_get_col $rs 0 bet_id]
        }

        db_close $rs

        return $bet_id
    }

    proc get_first_user {$current_move_id $other_move_id} {
        set current_first_bet_id [get_first_user_bet_id $current_move_id]
        set other_first_bet_id [get_first_user_bet_id $other_move_id]

        if {$other_first_bet_id == ""} {
            return "current"
        } elseif {$current_first_bet_id < $other_first_bet_id} {
            return "current"
        } else {
            return "other"
        }
    }

    proc get_turn_number {game_id} {
        global DB

        set sql {
            SELECT
                MAX(turn_number) as turn_number
            FROM
                twargamemoves
            WHERE
                game_id = ?
        }


        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby_page.html
			return
		}
		if {[catch {set rs [inf_exec_stmt $stmt $game_id]} msg]} {
			tpBindString err_msg "error occured while executing query"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby_page.html
			return
		}

        catch {inf_close_stmt $stmt}

        set max [db_get_col $rs 0 turn_number]

        db_close $rs

        return $max
    }

    proc get_card_amount {game_id player_id turn_number} {
        global DB

        set sql {  
            SELECT
                COUNT(hand_card.card_id) as card_amount
            FROM
                thand as hand,
                thand_card as hand_card,
                twargamemoves as moves
            WHERE
                hand.hand_id = hand_card.hand_id AND
                moves.hand_id = hand.hand_id AND
                hand.player_id = ? AND
                moves.turn_number = ? AND
                moves.game_id = ?

        }

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby_page.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt $player_id $turn_number $game_id]} msg]} {
			tpBindString err_msg "error occured while executing query"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby_page.html
			return
		}

        catch {inf_close_stmt $stmt}

        set result [db_get_col $rs 0 card_amount]

        db_close $rs

        return $result
    }

    proc get_user_id_in_room {room_id} { 
        global DB

        set RESULTS {}

        set sql {   
            SELECT
                user_id
            FROM
                tactivewaruser
            WHERE
                room_id = ?
        }

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby_page.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt $room_id]} msg]} {
			tpBindString err_msg "error occured while executing query"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby_page.html
			return
		}

        catch {inf_close_stmt $stmt}

        set RESULT(player1_id) ""
        set RESULT(player2_id) ""

        if {[db_get_nrows $rs] > 0} {
            set RESULT(player1_id) [db_get_col $rs 0 user_id]
        } 
        
        if {[db_get_nrows $rs] > 1} {
            set RESULT(player2_id) [db_get_col $rs 1 user_id]
        } 

        catch {db_close $rs}

        return [list $RESULT(player1_id) $RESULT(player2_id)]
    }

    proc game_state_json args {
        global DB

        set user_id [reqGetArg user_id]
        set room_id [reqGetArg room_id]
        set game_id [reqGetArg game_id]

        set current_user_id $user_id
        set other_user_id {}
        
        set ret_players [get_user_id_in_room $room_id]

        set PLAYERS(player1_id) [lindex $ret_players 0]
        set PLAYERS(player2_id) [lindex $ret_players 1]

        set sess_id [get_active_user $user_id]

        if {$PLAYERS(player1_id) == $user_id} {
            set other_user_id $PLAYERS(player2_id)
        } elseif {$PLAYERS(player2_id) == $user_id} {
            set other_user_id $PLAYERS(player1_id)
        } else { #players have disconnected!

            set winner_details [get_winner $game_id]
            set WINNER(winner_id) [lindex $winner_details 0]
            set WINNER(winner_username) [lindex $winner_details 1]
            set WINNER(win_condition) [lindex $winner_details 2]

            set winner $WINNER(winner_username)
            set win_condition $WINNER(win_condition)
            set loser "The opponent"

            tpBindString JSON "\{\"sess_id\": \"$sess_id\"\, \"condition\": \"finished\", \"winner\": \"$winner\", \"loser\": \"$loser\", \"win_condition\": \"$win_condition\"\}"
            asPlayFile -nocache war_games/jsonTemplate.json
            return
        }

        set user_username [get_username $user_id]
        set other_user_username [get_username $other_user_id]

        set current_user_current_turn [get_turn_number $game_id]
        set other_current_turn [get_turn_number $game_id]
        set current_user_card_amount [get_card_amount $game_id $current_user_id $current_user_current_turn]
        set other_card_amount [get_card_amount $game_id $other_user_id $other_current_turn]

        set current_turn ""

        set current_move_id [get_moves_id $game_id $current_user_id $current_user_current_turn]

        if {$current_user_current_turn > $other_current_turn} {
            set current_turn $current_user_current_turn
        } else {
            set current_turn $other_current_turn
        }

        set final_bet_id    [get_final_bet_id $game_id $current_turn]
        set bet_turn        [get_bet_turn $final_bet_id]

        set viewable_card ""
        set viewable_location -1
        set other_specific_card ""
        set suit ""

        set card_id [get_turned_card $current_user_id $game_id $current_user_current_turn]
        if {$card_id != ""} {
            #$entire_hand($card_location,card_id)
            array set entire_hand [get_entire_hand $user_id $current_move_id]
            array set specific_card [get_specific_card $card_id]
            set viewable_card $specific_card(0,card_name)
            set suit $specific_card(0,suit_name)

            for {set i 0} {$i < $current_user_card_amount} {incr i} {
                if {$entire_hand($i,card_id) == $card_id} {
                    set viewable_location $i
                    break
                }
            }
        }


        set other_suit ""
        if {$current_turn > 0} {
            set card_id_2 [get_turned_card $other_user_id $game_id [expr $other_current_turn - 1]]
            array set specific_card [get_specific_card $card_id_2]
            set other_specific_card $specific_card(0,card_name)
            set other_suit $specific_card(0,suit_name)
        }
        set card_id_2 [get_turned_card $other_user_id $game_id $other_current_turn]
        if {$card_id_2 != ""} {
            set other_specific_card "picked"
            set other_suit ""

        }

        set user_move_id [get_moves_id $game_id $current_user_id $current_user_current_turn]
        set other_user_move_id [get_moves_id $game_id $other_user_id $other_current_turn]

        set bet_value [get_latest_bet $user_move_id]
        set user2_bet_value [get_latest_bet $other_user_move_id]

        set this_balance [game_balance $current_user_id $room_id]
        set other_balance [game_balance $other_user_id $room_id]



        if {$this_balance == 0 || $current_user_card_amount == 0} {
            update_win_game $game_id $other_user_id STANDARD
        } elseif {$other_balance == 0 || $other_card_amount == 0} {
            update_win_game $game_id $user_id STANDARD
        }

        set condition "finished"

        # Check whether the player has won or lost
        set winner_details [get_winner $game_id]
        set WINNER(winner_id) [lindex $winner_details 0]
        set WINNER(winner_username) [lindex $winner_details 1]
        set WINNER(win_condition) [lindex $winner_details 2]

        set winner $WINNER(winner_username)
        set win_condition $WINNER(win_condition)

        if {$WINNER(winner_id) == $user_id} {
            set loser $other_user_username
        } elseif {$WINNER(winner_id) == $other_user_id} {
            set loser $user_username
        } else {
            set loser ""
            set winner ""
            set win_condition ""
            set condition "playing"
        }


        if {$PLAYERS(player1_id) == $user_id} {
            set other_user_id $PLAYERS(player2_id)
            set player_bet_turn 0
        } elseif {$PLAYERS(player2_id) == $user_id} {
            set player_bet_turn 1
            set other_user_id $PLAYERS(player1_id)
        } else {
            return
        }      

        if {[expr $current_turn % 2] == 1} {
            set player_bet_turn [expr 1 - $player_bet_turn]
        } 

        set player_turn ""

        if {[expr $bet_turn % 2] == $player_bet_turn} {
            set player_turn $other_user_id
        } else {
            set player_turn $user_id
        }

        
        if {[expr $current_user_card_amount + $other_card_amount] == 10} {
            set prev_winner_move_id ""
            set prev_loser_move_id ""

            set prev_loser_hand(0,card_id) ""
            set prev_winner_hand(0,card_id) ""

            set prev_winner_hand_length ""
            set prev_loser_hand_length ""

            set prev_total_hand_length ""

            set back_step 1
            while {1 == 1} {
                set prev_winner_move_id [get_moves_id $game_id $user_id [expr $current_turn - $back_step]]
                set prev_loser_move_id [get_moves_id $game_id $other_user_id [expr $current_turn - $back_step]]

                array set prev_loser_hand [get_entire_hand $other_user_id $prev_loser_move_id]
                array set prev_winner_hand [get_entire_hand $user_id $prev_winner_move_id]

                set prev_loser_hand_length [expr [array size prev_loser_hand] / 3]
                set prev_winner_hand_length [expr [array size prev_winner_hand] / 3]

                set prev_total_hand_length [expr $prev_loser_hand_length + $prev_winner_hand_length]

                if {$prev_total_hand_length == 10} {
                    set back_step [expr $back_step + 1]
                } else {
                    break
                }
            }

            set bet_value [get_latest_bet $prev_winner_move_id]
            set user2_bet_value [get_latest_bet $prev_loser_move_id]
        }

        set winner_json $winner
        set loser_json $loser
        set win_condition_json $win_condition


        set json "\{\"username\": \"$user_username\", \"bet_value\": \"$bet_value\", \"current_turn\": $current_turn, \"user_balance\": $this_balance, \"user_card_amount\" : $current_user_card_amount, \
            \"viewable_card\": \{\"viewable_turn\": $current_user_current_turn, \"viewable_location\": $viewable_location, \"specific_card\": \"$viewable_card\", \"suit_name\": \"$suit\"\}, \
            \"user2\": \{\"username\": \"$other_user_username\", \"bet_value\": \"$user2_bet_value\", \"specific_card\": \"$other_specific_card\", \"suit_name\": \"$other_suit\", \"viewable_turn\": $other_current_turn, \"user2_balance\": $other_balance, \"user2_card_amount\": $other_card_amount\},
            \"condition\": \"$condition\", \"winner\": \"$winner_json\", \"loser\": \"$loser_json\", \"win_condition\": \"$win_condition_json\", \"player_turn\": \"$player_turn\", \"sess_id\": $sess_id\}"

        tpBindString JSON $json

        asPlayFile -nocache war_games/jsonTemplate.json
    }

    proc get_winner {game_id} {
        global DB

        set sql {
            SELECT
                g.winner_id,
                u.username, 
                wc.win_condition
            FROM 
                twarwincondition wc,
                twargame g,
                twaruser u
            WHERE
                g.game_id = ? AND
                u.user_id = g.winner_id AND
                wc.win_condition_id = g.win_condition_id;
        }

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby.html
			return
		}

		if {[catch {set rs [inf_exec_stmt $stmt $game_id]} msg]} {
			tpBindString err_msg "error occured while executing query"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby.html
			return
		}

        catch {inf_close_stmt $stmt}

        set user_id ""
        set username ""
        set win_condition ""

        if {[db_get_nrows $rs] > 0} {
            set user_id [db_get_col $rs 0 winner_id]
            set username [db_get_col $rs 0 username]
            set win_condition [db_get_col $rs 0 win_condition]
        }

        catch {db_close $rs}

        return [list $user_id $username $win_condition]
    }

        proc get_username {user_id} {
        global DB

        set sql {
            SELECT 
                username
            FROM 
                twaruser
            WHERE
                user_id = ?
        }

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

		if {[catch {set rs [inf_exec_stmt $stmt $user_id]} msg]} {
			tpBindString err_msg "Please enter a non-empty username!"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}

        set username [db_get_col $rs 0 username]

        catch {db_close $rs}

        return $username
    }

    proc leave_waiting_room args {
        global DB

        set user_id     [reqGetArg user_id]
        set room_id     [reqGetArg room_id]
        set game_id     [reqGetArg game_id]

        update_last_active $user_id

        if { $game_id == "" } {
            set game_exists 0 
        } else {
            set game_exists [is_room $room_id $game_id]
        }

        if { $game_exists == 1} {

            set ret_players     [get_user_id_in_room $room_id]

            set PLAYERS(player1_id)     [lindex $ret_players 0]
            set PLAYERS(player2_id)     [lindex $ret_players 1]

            set other_user_id {}
            set current_user_id $user_id
            
            if {$PLAYERS(player1_id) == $user_id} {
                set other_user_id $PLAYERS(player2_id)
                set player_bet_turn 0
            } elseif {$PLAYERS(player2_id) == $user_id} {
                set player_bet_turn 1
                set other_user_id $PLAYERS(player1_id)
            } else {
                return
            } 


            set current_turn [get_turn_number $game_id ]
            end_game $current_user_id $other_user_id $room_id $game_id $current_turn
        }

        set sql {
            UPDATE 
                tactivewaruser 
            SET 
                room_id = NULL
            WHERE 
                user_id = ?
        }

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
            tpBindString err_msg "error occured while preparing statement"
            ob::log::write ERROR {===>error: $msg}
            tpSetVar err 1
            asPlayFile -nocache war_games/lobby.html
            return
        }
        
        if {[catch {inf_exec_stmt $stmt $user_id} msg]} {
            tpBindString err_msg "error occured while executing query"
            ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
            tpSetVar err 1
            asPlayFile -nocache war_games/lobby.html
            return
        }

        catch {inf_close_stmt $stmt}

        tpBindString user_id $user_id

        set user_balance [get_user_balance $user_id]
        set username [get_username $user_id]

        tpBindString user_balance $user_balance
        tpBindString username $username

        asPlayFile -nocache war_games/lobby_page.html
    }

    proc leave_room args {
        global DB

        set user_id     [reqGetArg user_id]
        set room_id     [reqGetArg room_id]
        set game_id     [reqGetArg game_id]

        update_last_active $user_id

        if { $game_id == "" } {
            set game_exists 0 
        } else {
            set game_exists [is_room $room_id $game_id]
        }

        if { $game_exists == 1} {

            set ret_players     [get_user_id_in_room $room_id]

            set PLAYERS(player1_id)     [lindex $ret_players 0]
            set PLAYERS(player2_id)     [lindex $ret_players 1]

            set other_user_id {}
            set current_user_id $user_id
            
            if {$PLAYERS(player1_id) == $user_id} {
                set other_user_id $PLAYERS(player2_id)
                set player_bet_turn 0
            } elseif {$PLAYERS(player2_id) == $user_id} {
                set player_bet_turn 1
                set other_user_id $PLAYERS(player1_id)
            } else {
                return
            } 


            set current_turn [get_turn_number $game_id ]


            end_game $current_user_id $other_user_id $room_id $game_id $current_turn

            set sql {
                UPDATE 
                    tactivewaruser 
                SET 
                    room_id = NULL
                WHERE 
                    room_id = ?
            }

            if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
                tpBindString err_msg "error occured while preparing statement"
                ob::log::write ERROR {===>error: $msg}
                tpSetVar err 1
                asPlayFile -nocache war_games/lobby.html
                return
            }
            
            if {[catch {inf_exec_stmt $stmt $room_id} msg]} {
                tpBindString err_msg "error occured while executing query"
                ob::log::write ERROR {===>error: $msg}
                catch {inf_close_stmt $stmt}
                tpSetVar err 1
                asPlayFile -nocache war_games/lobby.html
                return
            }

            catch {inf_close_stmt $stmt}


        }

        tpBindString user_id $user_id

        set user_balance [get_user_balance $user_id]
        set username [get_username $user_id]

        tpBindString user_balance $user_balance
        tpBindString username $username

        asPlayFile -nocache war_games/lobby_page.html
    }

    proc get_waiting_room_json args {
        global DB

        set room_id [reqGetArg room_id]

        set sql {
            select 
                user_id
            from
                tactivewaruser
            where
                room_id = ?
        }

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby_page.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt $room_id]} msg]} {
			tpBindString err_msg "error occured while executing query"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby_page.html
			return
		}

        catch {inf_close_stmt $stmt}

        set player1_id ""
        set player2_id ""
        if {[db_get_nrows $rs] > 0} {
            set player1_id [db_get_col $rs 0 user_id]
            update_last_active $player1_id
        }

        if {[db_get_nrows $rs] > 1} {
            set player2_id [db_get_col $rs 1 user_id]
            update_last_active $player2_id
        }
        

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
        set game_id    [room_id_to_game_id $room_id]

        update_last_active $user_id

        # Done to prevent two queries from loading at once (move to waiting room so that both users can obtain game_id)
        if {$user_id == $player2_id} {
            set p2_card_amount [get_card_amount $game_id $player2_id 0]
            #so that player can't hack many cards
            if {$p2_card_amount == 0} {
                create_final_bet $game_id 0
                #assigns the cards to each user
                array set MOVE_ID [initial_card_assigner $player1_id $player2_id $game_id $room_id]
                set player_1_move_id $MOVE_ID(0,move_id)
                set player_2_move_id $MOVE_ID(1,move_id)
            }
        }

        #start_game_update_user_balance $user_id $room_id

        tpBindString room_id $room_id
        tpBindString user_id $user_id
        tpBindString game_id $game_id
        # Send to HTML page
        asPlayFile -nocache war_games/game_page.html
    }
    
    proc get_lobbies_json args {
        global DB

        set user_id [reqGetArg user_id]

        set sql {
            SELECT
                tr.room_id,
                tr.starting_money,
                MAX(CASE WHEN ru.user_rank = 1 THEN ru.username END) AS player1_username,
                MAX(CASE WHEN ru.user_rank = 2 THEN ru.username END) AS player2_username,
                CASE 
                    WHEN tr.starting_money <= twu.acct_bal THEN 'true'
                    ELSE 'false'
                END AS can_afford
            FROM
                tactivewarroom tr
            LEFT JOIN
                (
                    SELECT
                        tu.room_id,
                        tu.user_id,
                        u.username,
                        ROW_NUMBER() OVER (PARTITION BY tu.room_id ORDER BY tu.sess_id) AS user_rank
                    FROM
                        tactivewaruser tu
                    LEFT JOIN
                        twaruser u ON tu.user_id = u.user_id
                    WHERE
                        tu.room_id IS NOT NULL
                ) AS ru ON tr.room_id = ru.room_id
            LEFT JOIN
                twaruser twu ON twu.user_id = ?
            GROUP BY
                tr.room_id,
                tr.starting_money,
                can_afford
            ORDER BY
                tr.room_id;
        }

         if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby_page.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt $user_id]} msg]} {
			tpBindString err_msg "error occured while executing query"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby_page.html
			return
		}

        catch {inf_close_stmt $stmt}

        set num_rooms [db_get_nrows $rs]
		tpSetVar num_rooms $num_rooms
	
        set lobbies ""

        # Note - refactor to ensure setplayerid and only change which player gets the thing and return the result
        for {set i 0} {$i < $num_rooms} {incr i} {
            set roomid "\"roomid\": [db_get_col $rs $i room_id]"
            set starting_money "\"starting_money\": [db_get_col $rs $i starting_money]"
            set can_afford "\"can_afford\": [db_get_col $rs $i can_afford]"
            set status {"closed"}

            if {[set username_1 [db_get_col $rs $i player1_username]] == ""} {
                set username_1 {None}
                set status {"open"}
            }

            if {[set username_2 [db_get_col $rs $i player2_username]] == ""} {
                set username_2 {None}
                set status {"open"}
            }

            set status "\"status\": $status"
            set player1_username "\"player1_username\": \"$username_1\""
            set player2_username "\"player2_username\": \"$username_2\""

            if {$i == 0} {
                set lobbies "\{$roomid, $player1_username, $player2_username, $status, $starting_money, $can_afford\}"
            } else {
                set lobbies "$lobbies, \{$roomid, $player1_username, $player2_username, $status, $starting_money, $can_afford\}"
            }
        }

        catch {db_close $rs}

        set sess_id [get_active_user $user_id]
		
		set json "\{\"lobbies\": \[$lobbies\], \"sess_id\": \"$sess_id\"\}"
        tpBindString JSON $json
        
        asPlayFile -nocache war_games/jsonTemplate.json
    }

    proc go_login_page args {
        asPlayFile -nocache war_games/login.html
    }

    # Refactor this and get_user_id - abstract, we are repeating code
    proc get_user_json args {
        global DB

        set input_username [reqGetArg username]

        set sql {
            SELECT 
                user_id, username
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
		
		if {[catch {set rs [inf_exec_stmt $stmt $input_username]} msg]} {
			tpBindString err_msg "Please enter a non-empty username!"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}

        set json ""
        set user_id {""}
        set username {""}

        if {[db_get_nrows $rs] > 0} {
            set user_id  [db_get_col $rs 0 user_id]
            set username "\"[db_get_col $rs 0 username]\""
        }

        catch {db_close $rs}

        set json "{\"user_id\": $user_id, \"username\": $username}"

        tpBindString JSON $json
        asPlayFile -nocache war_games/jsonTemplate.json
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
			tpBindString err_msg "Please enter a non-empty username!"
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


    # This is called when login successful
    proc create_user {username} {
        global DB

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
			tpBindString err_msg "Cannot enter an empty username!"
			ob::log::write ERROR {===>error2: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}
    }
    
    # This is called when login successful
    proc go_lobby_page args {
        set user_id [reqGetArg user_id]
        tpBindString user_id $user_id
        set user_balance [get_user_balance $user_id]
        set username [get_username $user_id]

        update_last_active $user_id

        tpBindString user_balance $user_balance
        tpBindString username $username

        asPlayFile -nocache war_games/lobby_page.html
    }

        # Rename for similar naming
    proc go_room_page args {
        global DB

        set user_id [reqGetArg user_id]
        set room_id [reqGetArg room_id]

        tpBindString user_id $user_id
        update_last_active $user_id

        set room_status [check_room_status $room_id]

        if {$room_status != "closed"} {
             insert_user_to_room $user_id $room_id
        }
        if {$room_status == "closed"} {
            asPlayFile -nocache war_games/lobby_page.html
            return
        } elseif {$room_status == "empty"} {
            # Done to prevent two queries from loading at once (move to waiting room so that both users can obtain game_id)
            #insert game
            set sql {
                INSERT INTO twargame (cr_date)
                VALUES (CURRENT YEAR TO SECOND);
            }
                

            if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
                tpBindString err_msg "error occured while preparing statement"
                ob::log::write ERROR {===>error: $msg}
                tpSetVar err 1
                asPlayFile -nocache war_games/lobby_page.html
                return
            }
                
            if {[catch {inf_exec_stmt $stmt} msg]} {
                tpBindString err_msg "error occured while executing query"
                ob::log::write ERROR {===>error: $msg}
                catch {inf_close_stmt $stmt}
                tpSetVar err 1
                asPlayFile -nocache war_games/lobby_page.html
                return
            }

            catch {inf_close_stmt $stmt}

            set game_id [last_pk]

            #update room

            set sql {
                UPDATE tactivewarroom
                SET game_id = ?
                WHERE room_id = ?;
            }

            if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
                tpBindString err_msg "error occured while preparing statement"
                ob::log::write ERROR {===>error: $msg}
                tpSetVar err 1
                asPlayFile -nocache war_games/lobby_page.html
                return
            }
                
            if {[catch {inf_exec_stmt $stmt $game_id $room_id} msg]} {
                tpBindString err_msg "error occured while executing query"
                ob::log::write ERROR {===>error: $msg}
                catch {inf_close_stmt $stmt}
                tpSetVar err 1
                asPlayFile -nocache war_games/lobby_page.html
                return
            }
        }


        tpBindString room_id $room_id
        asPlayFile -nocache war_games/waiting_room.html
    }

    proc check_room_status {room_id} {
        global DB 

        set sql {
            select 
                user_id
            from 
                tactivewaruser
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
			ob::log::write ERROR {===>error2: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby.html
			return
		}

        catch {inf_close_stmt $stmt}

        set status "open"

        if {[db_get_nrows $rs] >= 2} {
            set status "closed"
        } elseif {[db_get_nrows $rs] == 0} {
            set status "empty"
        }

        catch {db_close $rs}
        return $status
    }

    # Remove player on front end
    proc insert_user_to_room {user_id room_id} {
        global DB
        ;#sql query refactor
        set sql {
            update 
                tactivewaruser
            set 
                room_id = ?
            where 
                user_id = ?
        }

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby.html
			return
		}
		
		if {[catch {inf_exec_stmt $stmt $room_id $user_id} msg]} {
			tpBindString err_msg "error occured while executing query"
			ob::log::write ERROR {===>error2: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby.html
			return
		}

        catch {inf_close_stmt $stmt}
    }

    proc go_game_page args {
        update_last_active $user_id
        asPlayFile -nocache war_games/game_page.html
    }
    
}