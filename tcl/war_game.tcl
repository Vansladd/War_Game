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
    asSetAct WAR_GAME_Flip_card             [namespace code flip_card]

    asSetAct WAR_GAME_Inital_bet            [namespace code initial_bet]

    asSetAct WAR_GAME_User_JSON             [namespace code get_user_json]
    asSetAct WAR_GAME_Lobbies_JSON          [namespace code get_lobbies_json]
    asSetAct WAR_GAME_Waiting_Room_JSON     [namespace code get_waiting_room_json]
    asSetAct WAR_GAME_game_state_JSON       [namespace code game_state_json]
    

    proc create_final_bet {game_id turn_number user_id} {
        global DB

        set sql {
            INSERT INTO twarbetfinal(game_id, turn_number)
            VALUES (?,?)
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

        set final_bet_id [last_pk]


        set sql {
            SELECT
                twarbetmoves.moves_id as moves_id
            FROM
                twarbetmoves,
                twaruser,
                tactivewaruser,
                tactivewarroom
            WHERE
                twarbetmoves.game_id = ? AND
                twarbetmoves.turn_number = ? AND
                twaruser.user_id = ? AND
                twaruser.user_id = tactivewaruser.user_id AND
                tactivewaruser.room_id = tactivewarroom.room_id AND
                tactivewarroom.game_id = twardbetmoves.game_id
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

        
        set moves_id [db_get_col $rs 0 moves_id]

        catch {db_close $rs}

        set sql {
            UPDATE twarbetmoves
                
            SET final_bet_id = ?
            FROM 
                twarbetmoves
            WHERE
                moves_id = ?

        }

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt $final_bet_id $moves_id]} msg]} {
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

    proc initial_bet args {
        global DB

        set bet [reqGetArg bet_value]
        set action [reqGetArg bet_action]

        set action_id [to_action_id $action]

        # set initial bet value
        # set user_id (which player made the bet)
        # set bet action (fold, raise, match)

        # create/search for final_bet_id
        # link new bet to final_bet_id 
        # insert into twarbet (bet_Value) (action) (user_id)
        set sql {
            INSERT INTO
                twarbetmove (bet_value, action_id, final_bet_id)
            VALUES
                (?, ?, 50);
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
		
		if {[catch [inf_exec_stmt $stmt $bet $action_id] msg]} {
			tpBindString err_msg "error occured while executing query"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}

    }


    proc clear_lobbies {} {

        set sql {
            DELETE FROM 
                tactivewaruser
        }

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

    proc do_login {user_id} {
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
    
    proc get_entire_hand {user_id game_id} {
       global DB

       global HAND
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
                game_moves.game_id = ?
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
		
		if {[catch {set rs [inf_exec_stmt $stmt $user_id $game_id]} msg]} {
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


        #getting users entire hand
        array set entire_hand [get_entire_hand $user_id $game_id]

        

        #get users chosen card
        set specific_card_id $entire_hand($card_location,card_id)


        #getting specific card attributes
        array set specific_card [get_specific_card $specific_card_id]

        #getting the number of turns the user did
        set turn_number [get_turn_number $game_id $user_id]

        set turn_number [expr $turn_number + 0]

        set game_bal 50
        set final_bet_id -1


        #inserting change in database
        insert_game_moves $game_id $entire_hand(0,hand_id) $turn_number $game_bal $specific_card_id $final_bet_id

        tpBindString room_id $room_id
        tpBindString user_id $user_id

        go_game_page


    }

    # UPDATE LAST ACTIVE USER!!!! Use when user makes a new action
    # Not sure whether to call this directly from the front-end or call this with back-end methods that are called when the user navigates to them
    proc update_last_active_user {user_id} {
        global DB

        set sql {
            update
                tactivewaruser
            set 
                last_active = dbinfo('current_utc')
            where 
                user_id = ?
        }

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
            tpBindString err_msg "error occured while preparing statement"
            ob::log::write ERROR {===>error: $msg}
            tpSetVar err 1
            asPlayFile -nocache war_games/lobby_page.html
            return
        }
            
        if {[catch [inf_exec_stmt $stmt $user_id] msg]} {
            tpBindString err_msg "error occured while executing query"
            ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
            tpSetVar err 1
            asPlayFile -nocache war_games/lobby_page.html
            return
        }

        catch {inf_close_stmt $stmt}
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

        set this_balance 50

        set other_balance 50

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

        


        set json "\{\"current_turn\": $current_turn, \"user_balance\": $this_balance, \"user_card_amount\" : $current_user_card_amount, \"condition\": \"$condition\", \
            \"viewable_card\": \{\"viewable_turn\": $current_user_current_turn, \"viewable_location\": $viewable_location, \"specific_card\": \"$viewable_card\"\}, \
            \"user2\": \{\"specific_card\": \"$other_specific_card\", \"viewable_turn\": $other_current_turn, \"user2_balance\": $other_balance, \"user2_card_amount\": $other_card_amount\}\}"
        
        puts $json

        tpBindString JSON $json

        asPlayFile -nocache war_games/jsonTemplate.json

    }

    proc leave_room args {
        global DB

        set user_id     [reqGetArg user_id]

        ;#sql query refactor
        set sql [subst {
            UPDATE 
                tactivewaruser 
            SET 
                room_id = NULL
            WHERE 
                user_id = ?
        }]

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
            initial_card_assigner $player1_id $player2_id $game_id

            create_final_bet $game_id 0 $player1_id
            create_final_bet $game_id 0 $player2_id
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
        set sql {
            SELECT
                tr.room_id as room_id,
                MAX(CASE WHEN ru.user_rank = 1 THEN ru.user_id END) AS player1_id,
                MAX(CASE WHEN ru.user_rank = 2 THEN ru.user_id END) AS player2_id
            FROM
                tactivewarroom tr
            LEFT JOIN (
                SELECT
                    tu.room_id,
                    tu.user_id,
                    ROW_NUMBER() OVER (PARTITION BY tu.room_id ORDER BY tu.sess_id) AS user_rank
                FROM
                    tactivewaruser tu
                WHERE
                    tu.room_id IS NOT NULL
            ) AS ru ON tr.room_id = ru.room_id
            GROUP BY
                tr.room_id;
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

        catch {db_close $rs}
		
		set json "\{\"lobbies\": \[$lobbies\]\}"
        tpBindString JSON $json
        
        asPlayFile -nocache war_games/jsonTemplate.json
    }

    proc disconnect_timeout_users args {

        puts "---------------------------------------------> RUNNING SQL DELETE ACTIVE STATEMENTS!"

        global DB
        global SESSION

        set sql {
            select 
                sess_id, user_id
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
        }

        disconnect_users_in_rooms $num_users
        disconnect_users_in_games $num_users
        disconnect_active_users   $num_users
        
        catch {unset $SESSION}
        db_close $rs
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

        puts "-------------------------> EXECUTE DISCONNECT FROM ACTIVEUSERS!"

        catch {inf_close_stmt $stmt}
    }

    # NOTE: NOT DONE YET AS WE HAVE YET TO COMPLETE GAMES
    proc disconnect_users_in_games {num_users} {
        # Insert disconnect user from game logic here
        global DB
        global SESSION
        if {$num_users <= 0} {return}
    }

    proc disconnect_users_in_rooms {num_users} {
        global DB
        global SESSION

        if {$num_users <= 0} {return}

        # set where "player1_id = $SESSION(0,user_id) OR player2_id = $SESSION(0,user_id)"

        # for {set i 1} {$i < $num_users} {incr i} {
        #     set where "$where OR player1_id = $SESSION($i,user_id) OR player2_id = $SESSION($i,user_id)"            
        # }

        # set sql [subst {
        #     delete from 
        #         tactivewarroom
        #     where 
        #         $where  
        # }]

        # if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
		# 	tpBindString err_msg "error occured while preparing statement"
		# 	ob::log::write ERROR {===>error: $msg}
		# 	tpSetVar err 1
		# 	asPlayFile -nocache war_games/login.html
		# 	return
		# }
		
		# if {[catch [inf_exec_stmt $stmt] msg]} {
		# 	tpBindString err_msg "error occured while executing query"
		# 	ob::log::write ERROR {===>error: $msg}
        #     catch {inf_close_stmt $stmt}
		# 	tpSetVar err 1
		# 	asPlayFile -nocache war_games/login.html
		# 	return
		# }

        # puts "-------------------------> EXECUTE DISCONNECT FROM ROOMS!"

        # catch {inf_close_stmt $stmt}
    }

    proc go_login_page args {

        # Move this to an initialisation method (which could be referenced in the menu, and then you show the login page)
        # This has nothing to do with logging in after all
        if {![OT_CfgGet APP_IS_PMT 0]} {
        # Make child 0 the background child.
        # (Give it a 1 millisecond interval to start with so it will do the
        # timeout immediately after finishing main_init - it'll be set to the
        # proper interval after the timeout's been done the first time.
        # If we try to call timeout before main_init has completed, we cannot
        # play templates easily.)

            if {[asGetId] == 0 && [asGetGroupId] == 0} {
                asSetTimeoutProc     WAR_GAME::disconnect_timeout_users
                asSetTimeoutInterval 1000
                asSetReqAccept       0
                asSetReqKillTimeout  10000
            } else {
                after 500
            }
        }

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

    proc create_user {username} {
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
			tpBindString err_msg "Cannot enter an empty username!"
			ob::log::write ERROR {===>error2: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache war_games/login.html
			return
		}

        catch {inf_close_stmt $stmt}

        set user_id [get_user_id $username]

        do_login $user_id

        tpBindString user_id $user_id
        asPlayFile -nocache war_games/lobby_page.html
    }
    
    # This is called when login successful
    proc go_lobby_page args {
        set user_id [reqGetArg user_id]
        do_login $user_id
        tpBindString user_id $user_id
        asPlayFile -nocache war_games/lobby_page.html
    }

    # Rename for similar naming
    proc go_room_page args {
        global DB

        set user_id [reqGetArg user_id]
        set room_id [reqGetArg room_id]

        

        insert_user_to_room $user_id $room_id


        tpBindString user_id $user_id
        tpBindString room_id $room_id

        asPlayFile -nocache war_games/waiting_room.html
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