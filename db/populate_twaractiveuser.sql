DELETE FROM tactivewaruser;

INSERT INTO  
	tactivewaruser (user_id, last_active) 
VALUES 
	(6, dbinfo('utc_current')); 

INSERT INTO  
	tactivewaruser (user_id, last_active) 
VALUES 
	(7, dbinfo('utc_current') - 100); 

INSERT INTO  
	tactivewaruser (user_id, last_active) 
VALUES 
	(8, dbinfo('utc_current') - 200); 

 INSERT INTO  
	tactivewaruser (user_id, last_active) 
VALUES 
	(9, dbinfo('utc_current') - 600); 