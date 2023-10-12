INSERT INTO  
	tactivewaruser (user_id, last_active, room_id) 
VALUES 
	(89, dbinfo('utc_current') - 585, 4); 

delete from tactivewaruser where room_id = 4;

INSERT INTO  
	tactivewaruser (user_id, last_active, room_id) 
VALUES 
	(91, dbinfo('utc_current') - 585, 4); 

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
    room_id = 4;

SELECT DISTINCT
    tu.room_id,
    tr.game_id,
    CASE 
        WHEN tu.user_id IN (91) THEN tu2.user_id
        ELSE tu.user_id 
    END AS other_player_user_id
FROM
    tactivewaruser tu
INNER JOIN
    tactivewarroom tr
    ON tu.room_id = tr.room_id
LEFT JOIN
    tactivewaruser tu2
    ON tu.room_id = tu2.room_id
    AND tu2.user_id != tu.user_id
WHERE
    tu.user_id IN (91);

