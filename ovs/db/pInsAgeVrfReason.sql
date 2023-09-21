{
  ------------------------------------------------------------------------
  Copyright (c) Orbis Technology 2001. All rights reserved.
  ------------------------------------------------------------------------
  Insert an Age Verification status reason

  ------------------------------------------------------------------------
}
drop procedure pInsAgeVrfReason;

create procedure pInsAgeVrfReason(
	p_adminuser        like tAdminUser.username,
	p_reason_code      like tAgeVrfReason.reason_code,
	p_desc             like tAgeVrfReason.desc
);

	define v_user_id int;

	-- check admin authorisation
	let v_user_id = pCheckAdminAuth(
		p_username = p_adminuser,
		p_action   = 'VrfAgeManage'
	);

	-- $Id: pInsAgeVrfReason.sql,v 1.1 2011/10/04 12:40:38 xbourgui Exp $

	if p_reason_code == '' then
		raise exception -746,0,"Failed to insert into tAgeVrfReason - reason_code is empty";
	end if

	insert into tAgeVrfReason (
		reason_code,
		desc
	) values (
		p_reason_code,
		p_desc
	);

	if DBINFO('sqlca.sqlerrd2') <> 1 then
		raise exception -746,0,"Failed to insert into tAgeVrfReason";
	end if

end procedure;
