# ==============================================================
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
    asSetAct WAR_GAME_Join_Game             [namespace code go_join_game]
    asSetAct WAR_GAME_Leave_Room            [namespace code leave_room]
    asSetAct WAR_GAME_Flip_card             [namespace code flip_card]

    asSetAct WAR_GAME_Inital_bet            [namespace code initial_bet]

    asSetAct WAR_GAME_User_JSON             [namespace code get_user_json]
    asSetAct WAR_GAME_Lobbies_JSON          [namespace code get_lobbies_json]
    asSetAct WAR_GAME_Waiting_Room_JSON     [namespace code get_waiting_room_json]
    asSetAct WAR_GAME_game_state_JSON       [namespace code game_state_json]

    proc do_signup args {
        set username [reqGetArg username]
        create_user $username
        set user_id [get_user_id $username]

        set_active_session $user_id

        tpBindString user_id $user_id
        asPlayFile -nocache war_games/lobby_page.html
    }

    proc game_balance {user_id room_id} {
        global DB

        set game_id [room_id_to_game_id $room_id]
        set current_turn [get_turn_number $game_id $user_id]
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

        
        set bet_value [db_get_col $rs 0 bet_value]

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

    proc create_final_bet2 {} {
        global DB


        set sql {
            INSERT INTO twarbetfinal("final_bet_value")
            VALUES(0)
        }


        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt} msg]} {
			tpBindString err_msg "Please enter a non-empty username!"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}

        return [last_pk]
    }
    
    proc create_user_bet {bet_value game_id action_id final_bet_id} {
        global DB


        set sql {
            INSERT INTO twarbetmove(bet_value,game_id,action_id,final_bet_id)
            VALUES(?,?,?,?)
        }


        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt $bet_value $game_id $action_id $final_bet_id]} msg]} {
			tpBindString err_msg "Please enter a non-empty username!"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}


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

    proc create_final_bet {move_id} {
        global DB

        set sql {
            INSERT INTO twarbetfinal(final_bet_value)
            VALUES (0)
        }

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt]} msg]} {
			tpBindString err_msg "Please enter a non-empty username!"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}

        set final_bet_id [last_pk]

        #set bet_id [get_bet_id $game_id $turn_number $user_id]

        set sql {
            INSERT INTO twarbetmove (move_id, final_bet_id) VALUES (?, ?)

        }

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt $move_id $final_bet_id]} msg]} {
			tpBindString err_msg "Please enter a non-empty username!"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}


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




    proc new_turn {game_id loser_id winner_id room_id loser_bet_value winner_bet_value} {
        set loser_current_turn [get_turn_number $game_id $loser_id]

        set winner_current_turn [get_turn_number $game_id $winner_id]

        set loser_move_id [get_moves_id $game_id $loser_id $loser_current_turn]

        set loser_balance [game_balance $loser_id $room_id]

        array set loser_hand [get_entire_hand $loser_id $loser_move_id]


        set winner_move_id [get_moves_id $game_id $winner_id $winner_current_turn]

        set winner_balance [game_balance $winner_id $room_id]

        array set winner_hand [get_entire_hand $winner_id $winner_move_id]

        set winner_hand_length [expr [array size winner_hand] / 3]

        set loser_card_id [get_turned_card $loser_id $game_id $loser_current_turn]


        
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


        #randomises the deck of cards for current user (-1 because card was removed)
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




        set loser_hand_id [insert_hand $loser_id $game_id [array get loser_hand_compatible] [array size loser_hand_compatible] [expr $loser_current_turn + 1]]
        set winner_hand_id [insert_hand $winner_id $game_id [array get winner_hand_compatible] [array size winner_hand_compatible] [expr $winner_current_turn + 1]]

        #game_id hand_id turn_number game_bal card_id Final_bet_id

        puts "----------------------------> winner_bet_value $winner_bet_value"
        puts "----------------------------> loser_bet_value $loser_bet_value"

        set loser_move_id [insert_game_moves $game_id $loser_hand_id [expr $loser_current_turn + 1] [expr $loser_balance - $loser_bet_value] "" 0]
        set winner_move_id [insert_game_moves $game_id $winner_hand_id [expr $winner_current_turn + 1] [expr $winner_balance + $winner_bet_value] "" 0]

        create_final_bet $loser_move_id
        create_final_bet $winner_move_id
    }

    proc initial_bet args {
        global DB

        set bet [reqGetArg bet_value]
        set action [reqGetArg bet_action]
        set room_id [reqGetArg room_id]
        set user_id [reqGetArg user_id]
        set game_id [room_id_to_game_id $room_id]
        set turn_number [get_turn_number $game_id $user_id]
        set move_id [get_moves_id $game_id $user_id $turn_number]

        set action_id [to_action_id $action]



        set do_database 0

        if {$action == "FOLD"} {
          
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
            
            set current_turn [get_turn_number $game_id $current_user_id]

            set current_move_id [get_moves_id $game_id $current_user_id $current_turn]
            set other_move_id [get_moves_id $game_id $other_user_id $current_turn]

            set other_bet_value [get_latest_bet $other_move_id]
            if {$other_bet_value == ""} {
                set other_bet_value 0
            }

            set current_bet_value [get_latest_bet $current_move_id]
            if {$current_bet_value == ""} {
                set current_bet_value 0
            }

            
            new_turn $game_id $current_user_id $other_user_id $room_id $current_bet_value $current_bet_value
            set bet [get_latest_bet $move_id]
            if {$bet == ""} {
                set bet 0
            }

        } elseif {$action == "MATCH"} {
            
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

            set current_user_current_turn [get_turn_number $game_id $current_user_id]

            set other_current_turn [get_turn_number $game_id $other_user_id]

            set user_move_id [get_moves_id $game_id $current_user_id $current_user_current_turn]
            set other_user_move_id [get_moves_id $game_id $other_user_id $other_current_turn]


            set current_user_card_id [get_turned_card $current_user_id $game_id $current_user_current_turn]
            set other_user_card_id [get_turned_card $other_user_id $game_id $other_current_turn]

            array set current_user_card_attributes [get_specific_card $current_user_card_id]
            array set other_user_card_attributes [get_specific_card $other_user_card_id]

            set loser_id ""
            set winner_id ""

            if {$current_user_card_attributes(0,card_value) > $other_user_card_attributes(0,card_value)} {
                set winner_id $current_user_id
                set loser_id $other_user_id
            } elseif {$current_user_card_attributes(0,card_value) < $other_user_card_attributes(0,card_value)} {
                set loser_id $current_user_id
                set winner_id $other_user_id
            } else {
                #does stuff
                # get loser and winner from tie but with 10 cards 
            }


            set loser_move_id [get_moves_id $game_id $loser_id $current_user_current_turn]
            set winner_move_id [get_moves_id $game_id $winner_id $other_current_turn]

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
                new_turn $game_id $loser_id $winner_id $room_id $bet_val $bet_val
                puts "----------------------- $do_database"
                set bet $winner_bet_value
            }

        } elseif {$action == "BET"} {

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

            set current_user_current_turn [get_turn_number $game_id $current_user_id]

            set user_move_id [get_moves_id $game_id $current_user_id $current_user_current_turn]

            set last_user_bet [get_latest_bet $user_move_id]
            if {$last_user_bet == ""} {
                set last_user_bet 0
            }

            set other_user_current_turn [get_turn_number $game_id $other_user_id]

            set other_move_id [get_moves_id $game_id $other_user_id $other_user_current_turn]

            set last_other_user_bet [get_latest_bet $other_move_id]

            if {$last_other_user_bet == ""} {
                set last_other_user_bet 0
            }

            set user_balance [game_balance $current_user_id $room_id]
            set other_balance [game_balance $other_user_id $room_id]

            puts "---------------------------------------> last_user_bet $last_user_bet"
            puts "---------------------------------------> last_other_user_bet $last_other_user_bet"

            if {$last_user_bet < $bet &&  $last_other_user_bet < $bet && $user_balance >= $bet && $other_balance >= $bet} {
                puts "===================== $bet"
                set do_database 1
            }
        }

        if {$do_database == 1} {
            set sql {
                INSERT INTO
                    twarbetmove (bet_value, action_id, move_id, final_bet_id)
                VALUES
                    (?, ?, ?, 0);
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
                
            if {[catch [inf_exec_stmt $stmt $bet $action_id $move_id] msg]} {
                tpBindString err_msg "error occured while executing query"
                ob::log::write ERROR {===>error: $msg}
                catch {inf_close_stmt $stmt}
                tpSetVar err 1
                asPlayFile -nocache war_games/login.html
                return
            }

            catch {inf_close_stmt $stmt}

        }
        tpBindString room_id $room_id
        tpBindString user_id $user_id

        go_game_page

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

        set card_id [db_get_col $rs 0 card_id]

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

        set CARD(0,card_value) [db_get_col $rs 0  card_value]
        set CARD(0,suit_name) [db_get_col $rs 0 suit_name]
        set CARD(0,card_name) [db_get_col $rs 0 card_name]

        db_close $rs

        return [array get CARD]

    }

    proc flip_card args {
        global DB

        set user_id             [reqGetArg user_id]
        set room_id             [reqGetArg room_id]
        set card_location       [reqGetArg card_location]
        set game_id             [room_id_to_game_id $room_id]
        set turn_number         [get_turn_number $game_id $user_id]
        set move_id             [get_moves_id $game_id $user_id $turn_number]

        #getting users entire hand
        array set entire_hand [get_entire_hand $user_id $move_id]



        #set final_bet_id [create_user_bet bet_value game_id action_id final_bet_id]

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

        tpBindString room_id $room_id
        tpBindString user_id $user_id

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
                
            if {[catch {set rs [inf_exec_stmt $stmt $game_id $hand_id $turn_number $game_bal $card_id $Final_bet_id]} msg]} {
                tpBindString err_msg "error occured while executing query"
                ob::log::write ERROR {===>error: $msg}
                catch {inf_close_stmt $stmt}
                tpSetVar err 1
                asPlayFile -nocache war_games/lobby_page.html
                return
            }
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
                
            if {[catch {set rs [inf_exec_stmt $stmt $card_id $Final_bet_id $game_id $hand_id $turn_number]} msg]} {
                tpBindString err_msg "error occured while executing query"
                ob::log::write ERROR {===>error: $msg}
                catch {inf_close_stmt $stmt}
                tpSetVar err 1
                asPlayFile -nocache war_games/lobby_page.html
                return
            }
        }


            catch {inf_close_stmt $stmt}

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
            
        if {[catch {set rs [inf_exec_stmt $stmt $player_id]} msg]} {
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
                
            if {[catch {set rs [inf_exec_stmt $stmt $hand_id $turn_number $CARDS($i)]} msg]} {
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

    proc initial_card_assigner {player1_id player2_id game_id} {
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
        for {set i 0} {$i < [expr $card_number]} {incr i} {
            if {$i < $each_player_card_number} {
                set player1_cards($i) $CARDS($i)
            } else {
                set offset [expr $i - $each_player_card_number]
                set player2_cards($offset) $CARDS($offset)
            }
        }

        #records the cards for each player in the database        
        set pl1_hand_id [insert_hand $player1_id $game_id [array get player1_cards] $each_player_card_number 0]
        set pl2_hand_id [insert_hand $player2_id $game_id [array get player2_cards] $each_player_card_number 0]

        set p1_bal 100
        set p2_bal 100

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

    proc get_turn_number {game_id player_id} {
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
		if {[catch {set rs [inf_exec_stmt $stmt $game_id $player_id]} msg]} {
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

        #if {$max == ""} {
       #     return 0
       # } else {
       #     return max
        #}
        return $max
    }

                #move.game_bal as game_bal, may not exist
                #bet_move.bet_value as bet_value, may not exist
                #action.action as action, may not exist
                #card.card_value as card_value, may not exist
                #suit.suit_name as suit_name,   may not exist
                #COUNT(hand_card.card_id) as card_amount #exist




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

        ;#sql query refactor
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

        set RESULT(player1_id) [db_get_col $rs 0 user_id]
        set RESULT(player2_id) [db_get_col $rs 1 user_id]

        db_close $rs



        return [list $RESULT(player1_id) $RESULT(player2_id)]

    }

    proc game_state_json args {
        global DB

        set user_id [reqGetArg user_id]


        set room_id [reqGetArg room_id]


        set game_id [room_id_to_game_id $room_id]

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




        set current_user_current_turn [get_turn_number $game_id $current_user_id]

        set other_current_turn [get_turn_number $game_id $other_user_id]

        set current_user_card_amount [get_card_amount $game_id $current_user_id $current_user_current_turn]

        set other_card_amount [get_card_amount $game_id $other_user_id $other_current_turn]

        set current_turn ""

        if {$current_user_current_turn > $other_current_turn} {
            set current_turn $current_user_current_turn
        } else {
            set current_turn $other_current_turn
        }


        set condition "playing"

        set viewable_card ""

        set viewable_location -1
        
        set other_specific_card ""

        set card_id [get_turned_card $current_user_id $game_id $current_user_current_turn]
        if {$card_id != ""} {
            #array set entire_hand [get_entire_hand $user_id $game_id]
            array set specific_card [get_specific_card $card_id]
            set viewable_card $specific_card(0,card_name)



        }
        set card_id_2 [get_turned_card $other_user_id $game_id $other_current_turn]
        if {$card_id_2 != ""} {
            array set specific_card [get_specific_card $card_id_2]
            set other_specific_card $specific_card(0,card_name)
        }

        if {$viewable_card == ""} {
            set other_specific_card ""
        }

        set user_move_id [get_moves_id $game_id $current_user_id $current_user_current_turn]
        set other_user_move_id [get_moves_id $game_id $other_user_id $other_current_turn]

        set bet_value [get_latest_bet $user_move_id]
        set user2_bet_value [get_latest_bet $other_user_move_id]


        set this_balance [game_balance $current_user_id $room_id]

        set other_balance [game_balance $other_user_id $room_id]

        #set bet_value [get_user_bet $game_id]
        #set user2_bet_value [get_user_bet]


        #current turn database
        #user balance database
        #user card amount database
        #condition database database
        #viewable card database
            #viewable turn delete
            #viewable location database [0] do a wait in javascript
            #specific card database
        #user2
            #specfic card
            #viewable turn delete
            #user2_balance database
            #user2_card_amount database

        


        set json "\{ \"bet_value\": \"$bet_value\", \"current_turn\": $current_turn, \"user_balance\": $this_balance, \"user_card_amount\" : $current_user_card_amount, \"condition\": \"$condition\", \
            \"viewable_card\": \{\"viewable_turn\": $current_user_current_turn, \"viewable_location\": $viewable_location, \"specific_card\": \"$viewable_card\"\}, \
            \"user2\": \{\"bet_value\": \"$user2_bet_value\", \"specific_card\": \"$other_specific_card\", \"viewable_turn\": $other_current_turn, \"user2_balance\": $other_balance, \"user2_card_amount\": $other_card_amount\}\}"

        tpBindString JSON $json

        asPlayFile -nocache war_games/jsonTemplate.json

    }

    proc leave_room args {
        global DB

        set user_id     [reqGetArg user_id]

        ;#sql query refactor
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

        asPlayFile -nocache war_games/lobby_page.html
    }

    proc get_waiting_room_json args {
        global DB

        set room_id [reqGetArg room_id]

        ;#sql query refactor
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

        }

        if {[db_get_nrows $rs] > 1} {
            set player2_id [db_get_col $rs 1 user_id]
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

        # Done to prevent two queries from loading at once
        if {$user_id == $player2_id} {


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
            
            if {[catch {set rs [inf_exec_stmt $stmt]} msg]} {
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
            
            if {[catch {set rs [inf_exec_stmt $stmt $game_id $room_id]} msg]} {
                tpBindString err_msg "error occured while executing query"
                ob::log::write ERROR {===>error: $msg}
                catch {inf_close_stmt $stmt}
                tpSetVar err 1
                asPlayFile -nocache war_games/lobby_page.html
                return
            }

            #assigns the cards to each user
            array set MOVE_ID [initial_card_assigner $player1_id $player2_id $game_id]
            set player_1_move_id $MOVE_ID(0,move_id)
            set player_2_move_id $MOVE_ID(1,move_id)

            create_final_bet $player_1_move_id
            create_final_bet $player_2_move_id
        }

        tpBindString room_id $room_id
        tpBindString user_id $user_id
        # Send to HTML page
        asPlayFile -nocache war_games/game_page.html
    }
    
    proc get_lobbies_json args {
        global DB
        # change sql select statement
        ;#sql query refactor

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
		
		set json "\{\"lobbies\": \[$lobbies\]\}"
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
        asPlayFile -nocache war_games/lobby_page.html
    }

        # Rename for similar naming
    proc go_room_page args {
        global DB

        set user_id [reqGetArg user_id]
        set room_id [reqGetArg room_id]

        tpBindString user_id $user_id

        if {[check_room_status $room_id] == "closed"} {
            asPlayFile -nocache war_games/lobby_page.html
            return
        }

        insert_user_to_room $user_id $room_id

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
        asPlayFile -nocache war_games/game_page.html
    }
    
}