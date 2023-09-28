# ==============================================================
# File path
# ~/git_src/induction/training/admin/tcl/war_games/war_game.tcl
# ==============================================================

namespace eval WAR_GAME {

	asSetAct WAR_GAME_Login                 [namespace code go_login_page]
    asSetAct WAR_GAME_Create_User           [namespace code create_user]
    asSetAct WAR_GAME_Lobby                 [namespace code go_lobby_page]
    asSetAct WAR_GAME_Game                  [namespace code go_game_page]
    asSetAct WAR_GAME_Waiting_Room          [namespace code go_room_page]
    asSetAct WAR_GAME_Join_Game             [namespace code go_join_game]
    asSetAct WAR_GAME_Leave_Room            [namespace code leave_room]

    asSetAct WAR_GAME_User_JSON             [namespace code get_user_json]
    asSetAct WAR_GAME_Lobbies_JSON          [namespace code get_lobbies_json]
    asSetAct WAR_GAME_Waiting_Room_JSON     [namespace code get_waiting_room_json]
    asSetAct WAR_GAME_game_state_JSON       [namespace code game_state_json]

    proc random_number {min max} {
        return [expr int((rand() * ($max + 1 - $min)) + $min)]
    }

    proc insert_game_moves {game_id hand_id turn_number game_bal card_id Final_bet_id} {
        global DB

        set insert ""
        set values ""
        if {$card_id == ""} {
            set insert "game_id, hand_id, turn_number, game_bal"
            set values "?, ?, ?, ?"
        } else {
            set insert "game_id, hand_id, turn_number, game_bal, card_id, Final_bet_id"
            set values "?, ?, ?, ?, ?, ?"
        }

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

            catch {inf_close_stmt $stmt}
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

        insert_game_moves $game_id $pl1_hand_id 0 $p1_bal "" ""
        insert_game_moves $game_id $pl2_hand_id 0 $p2_bal "" ""


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

        if {$max == ""} {
            return 0
        } else {
            return [expr [max + 1]]
        }

    }

                #move.game_bal as game_bal, may not exist
                #bet_move.bet_value as bet_value, may not exist
                #action.action as action, may not exist
                #card.card_value as card_value, may not exist
                #suit.suit_name as suit_name,   may not exist
                #COUNT(hand_card.card_id) as card_amount #exist




    proc get_card_amount {game_id player_id turn_number} {
        global DB

        set turn_number [expr $turn_number - 1]

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

        puts "========================== isnide count card  result = $result"
        return $result



    }

    proc get_game_move {game_id player_id turn_number} {
        global DB


        set turn_number [expr $turn_number - 1]

        set RESULTS {}

        set sql {
            SELECT
                move.game_bal as game_bal,
                bet_move.bet_value as bet_value,
                action.action as action,
                card.card_value as card_value,
                suit.suit_name as suit_name,
                COUNT(hand_card.card_id) as card_amount

            FROM
                twargamemoves as move,
                twarbetmove as bet_move,
                twarbetactions as action,
                thand as hand,
                thand_card as hand_card,
                twarcard as card,
                tsuit as suit,
                twarbetfinal as betfinal
            WHERE
                
                move.game_id = ? AND
                hand.player_id = ? AND
                move.turn_number = ? AND
                move.bet_id = bet_move.bet_id AND
                action.action_id = bet_move.action_id AND
                move.card_id = card.card_id AND
                hand.hand_id = move.hand_id AND
                hand_card.hand_id = hand.hand_id AND
                hand_card.turn_number = ? AND
                card.suit_id = suit.suit_id



        }


        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby_page.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt $game_id $player_id $turn_number]} msg]} {
			tpBindString err_msg "error occured while executing query"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby_page.html
			return
		}

        catch {inf_close_stmt $stmt}

        set RESULT(game_bal) [db_get_col $rs 0 game_bal]
        set RESULT(bet_value) [db_get_col $rs 0 bet_value]
        set RESULT(action) [db_get_col $rs 0 action]
        set RESULT(card_value) [db_get_col $rs 0 card_value]
        set RESULT(suit_name) [db_get_col $rs 0 suit_name]
        set RESULT(card_amount) [db_get_col $rs 0 card_amount]


        db_close $rs

        return RESULT

    }

    proc get_user_id_in_room {room_id} {
        global DB


        set RESULTS {}

        set sql {
            SELECT
                player1_id,
                player2_id

            FROM
                tactivewarroom

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

        set RESULT(player1_id) [db_get_col $rs 0 player1_id]
        set RESULT(player2_id) [db_get_col $rs 0 player2_id]

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



        set current_turn [get_turn_number $game_id $current_user_id]

        set player_1_card_amount [get_card_amount $game_id $PLAYERS(player1_id) $current_turn]

        set player_2_card_amount [get_card_amount $game_id $PLAYERS(player2_id) $current_turn]

        #set current_user [get_game_move $game_id $current_user_id $current_turn]

        #set other_user [get_game_move $game_id $other_user_id $current_turn]


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

        


        set json "\{\"current_turn\": 0, \"user_balance\": 50, \"user_card_amount\" : 5, \"condition\": \"playing\", \
            \"viewable_card\": \{\"viewable_turn\": -1, \"viewable_location\": -1, \"specific_card\": \"d4\"\}, \
            \"user2\": \{\"specific_card\": \"dk\", \"viewable_turn\": -1, \"user2_balance\": 50, \"user2_card_amount\": 5\}"
        
        tpBindString JSON $json

        asPlayFile -nocache war_games/jsonTemplate.json

    }

    proc leave_room args {
        global DB

        set user_id     [reqGetArg user_id]
        set room_id     [reqGetArg room_id]
        set player_id   [reqGetArg player_num_id]

        set sql [subst {
            UPDATE 
                tactivewarroom 
            SET 
                $player_id = NULL
            WHERE 
                room_id = ?
        }]

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

        tpBindString user_id $user_id

        asPlayFile -nocache war_games/lobby_page.html
    }

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
            initial_card_assigner $player1_id $player2_id $game_id

        }


        tpBindString room_id $room_id
        tpBindString user_id $user_id
        # Send to HTML page
        asPlayFile -nocache war_games/game_page.html
    }

    proc get_lobbies_json args {
        global DB
        # change sql select statement
        set sql {
            select
                room_id,
                player1_id,
                player2_id
            from 
                tactivewarroom;
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

        set num_rooms [db_get_nrows $rs]
		tpSetVar num_rooms $num_rooms
	

        set lobbies ""

        # Note - refactor to ensure setplayerid and only change which player gets the thing and return the result
        for {set i 0} {$i < $num_rooms} {incr i} {
            set roomid "\"roomid\": [db_get_col $rs $i room_id]"

            if {[set id_1 [db_get_col $rs $i player1_id]] == ""} {
                set id_1 {"Empty"}
            }

            if {[set id_2 [db_get_col $rs $i player2_id]] == ""} {
                set id_2 {"Empty"}
            }

            set player1_id "\"player1_id\": $id_1"
            set player2_id "\"player2_id\": $id_2"

            if {$i == 0} {
                set lobbies "\{$roomid, $player1_id, $player2_id\}"
            } else {
                set lobbies "$lobbies, \{$roomid, $player1_id, $player2_id\}"
            }
        }

        db_close $rs
		
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
			tpBindString err_msg "error occured while executing query"
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
            set username [db_get_col $rs 0 username]
        }

        set json "{\"user_id\": $user_id, \"username\": \"$username\"}"

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

    proc create_user args {
        global DB
    
        set username [reqGetArg username]

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

        set user_id [get_user_id $username]
        tpBindString user_id $user_id

        asPlayFile -nocache war_games/lobby_page.html
    }
    
    proc go_lobby_page args {
        asPlayFile -nocache war_games/lobby_page.html
    }

    # Rename for similar naming
    proc go_room_page args {
        global DB

        set user_id [reqGetArg user_id]
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
			ob::log::write ERROR {===>error2: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby.html
			return
		}

        catch {inf_close_stmt $stmt}

        set player1_id [db_get_col $rs 0 player1_id]
        set player2_id [db_get_col $rs 0 player2_id]

        catch {db_close $rs}

        if {$player1_id == ""} {
            insert_player_to_room player1_id $user_id $room_id
            tpBindString player_num_id player1_id
        } elseif {$player2_id == ""} {
            insert_player_to_room player2_id $user_id $room_id
            tpBindString player_num_id player2_id
        }

        catch {inf_close_stmt $stmt}

        tpBindString user_id $user_id
        tpBindString room_id $room_id

        asPlayFile -nocache war_games/waiting_room.html
    }

    proc insert_player_to_room {player player_id room_id} {
        global DB

        set sql [subst {
            update 
                tactivewarroom
            set 
                $player = ?
            where 
                room_id = ?
        }]

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/lobby.html
			return
		}
		
		if {[catch {inf_exec_stmt $stmt $player_id $room_id} msg]} {
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
        asPlayFile -nocache game_page.html
    }
    
}