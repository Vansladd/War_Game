INSERT INTO  
	tactivewaruser (user_id, last_active, room_id) 
VALUES 
	(89, dbinfo('utc_current') - 585, 3); 

INSERT INTO  
	tactivewaruser (user_id, last_active, room_id) 
VALUES 
	(91, dbinfo('utc_current') - 585, 3); 

DELETE FROM
    twargame
WHERE 
    game_id = 1;

INSERT INTO
    twargame (game_id, cr_date) 
VALUES
    (1, CURRENT YEAR TO SECOND); 

UPDATE
    tactivewarroom
SET
    game_id = 1    
WHERE
    room_id = 3;