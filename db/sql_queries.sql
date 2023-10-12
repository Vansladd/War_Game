SELECT COUNT(*) AS username_exists
FROM twaruser
WHERE username = ?;

SELECT COUNT(*) AS username_exists
FROM tactivewaruser
WHERE username = ?;

INSERT INTO twaruser (user_id, username, acct_bal)
VALUES (?, ?, ?);

INSERT INTO tactivewaruser (sess_id, user_id, cr_date)
VALUES (?, ?, ?);

INSERT INTO tactivewarroom (room_id, game_id, player1_id)
VALUES (?, ?, ?);

UPDATE tactivewarroom
SET player2_id = ?
WHERE room_id = ?;

INSERT INTO twargame (game_id,cr_date)
VALUES (?, ?);

delete from 
    tactivewaruser
where 
    sess_id in (
        select 
            sess_id 
        from 
            tactivewaruser 
        where 
            dbinfo('utc_current') - last_active > 600
);