{
  ------------------------------------------------------------------------
  Copyright (c) Orbis Technology 2001. All rights reserved.
  ------------------------------------------------------------------------
  Delete an Age Verification status reason

  ------------------------------------------------------------------------
}
drop procedure pDelAgeVrfReason;

create procedure pDelAgeVrfReason(
	p_adminuser        like tAdminUser.username,
	p_reason_code      like tAgeVrfReason.reason_code
);

	define v_user_id int;

	-- check admin authorisation
	let v_user_id = pCheckAdminAuth(
		p_username = p_adminuser,
		p_action   = 'VrfAgeManage'
	);

	-- $Id: pDelAgeVrfReason.sql,v 1.1 2011/10/04 12:40:38 xbourgui Exp $

	delete from
		tAgeVrfReason
	where
		reason_code = p_reason_code;

	if DBINFO('sqlca.sqlerrd2') <> 1 then
		raise exception -746,0,"Failed to delete from tAgeVrfReason";
	end if

end procedure;
