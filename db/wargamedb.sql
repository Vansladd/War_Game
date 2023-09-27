DROP TABLE IF EXISTS [tablename] 

create table twaruser 

( 

    user_id SERIAL not null, 

    username varchar(20) 	  UNIQUE not null, 

    acct_bal decimal(12,2) not null 

); 

  

alter table twaruser add constraint ( 

      primary key(user_id) 

            constraint cwaruser_pk 

); 

  

create table tactivewaruser 

( 

    sess_id SERIAL not null, 

    user_id int not null, 

    cr_date datetime year to second not null 

); 

  

alter table tactivewaruser add constraint ( 

      primary key(sess_id) 

            constraint cactivewaruser_pk 

); 

  

create table tactivewarroom 

( 

    room_id SERIAL not null, 

    game_id int null, 

    player1_id int null, 

    player2_id int null 

); 

  

alter table tactivewarroom add constraint ( 

      primary key(room_id) 

            constraint cactivewarroom_pk 

); 

  

create table twargame 

( 

    game_id SERIAL not null, 

    cr_date datetime year to second not null 

); 

  

alter table twargame add constraint ( 

      primary key(game_id) 

            constraint cwargame_pk 

); 

  

create table twarbetmove 

( 

    bet_id SERIAL not null, 

    bet_value decimal(12,2)  null, 

    action_id int not null, 

    final_bet_id int not null 

); 

  

alter table twarbetmove add constraint ( 

      primary key(bet_id) 

            constraint cwarbetmove_pk 

); 

  

create table twarbetfinal 

( 

    final_bet_id SERIAL not null, 

    Game_id int not null, 

   Turn_number int not null 

); 

 

  

alter table twarbetfinal add constraint ( 

      primary key(final_bet_id) 

            constraint cwarbetfinal_pk 

); 

  

create table twarbetactions 

( 

    action_id SERIAL not null, 

    action char(5) not null 

); 

  

alter table twarbetactions add constraint ( 

      primary key(action_id) 

            constraint cwarbetactions_pk 

); 

  

create table twargamemoves 

( 

    moves_id SERIAL not null, 

    game_id int not null, 

    hand_id int not null, 

    turn_number int not null, 

    game_bal decimal(12,2) not null, 

    card_id int null, 

    Final_bet_id int null 

); 

  

alter table twargamemoves add constraint ( 

      primary key(moves_id) 

            constraint cwargamemoves_pk 

); 

  

create table thand 

( 

    hand_id SERIAL not null, 

    player_id int not null 

); 

  

  

alter table thand add constraint ( 

      primary key(hand_id) 

            constraint chand_pk 

); 

  

create table thand_card 

( 

hand_card_id SERIAL not null, 

hand_id int not null, 

turn_number int not null, 

card_id int not null 

); 

  

create table twarcard 

( 

    card_id SERIAL not null, 

    suit_id int not null, 

    card_name char(16) not null, 

    card_value int not null 

); 

  

alter table twarcard add constraint ( 

      primary key(card_id) 

            constraint cwarcard_pk 

); 

  

create table tsuit 

( 

    suit_id SERIAL not null, 

    suit_name char(16) not null 

); 

  

alter table tsuit add constraint ( 

      primary key(suit_id) 

            constraint csuit_pk 

); 

  

create table troomcontrol 

( 

    room_change_id SERIAL not null, 

    room_id int not null, 

    change_type char(5) not null, 

    change_timestamp datetime year to second not null 

); 

  

alter table troomcontrol add constraint ( 

      primary key(room_change_id) 

            constraint croomcontrol_pk 

); 

  

create table tgamecontrol 

( 

    game_change_id SERIAL not null, 

    game_id int not null, 

    change_type char(5) not null, 

    change_timestamp datetime year to second not null 

); 

  

alter table tgamecontrol add constraint ( 

      primary key(game_change_id) 

            constraint cgamecontrol_pk 

); 
