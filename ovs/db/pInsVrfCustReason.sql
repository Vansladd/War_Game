{
  ------------------------------------------------------------------------
  Copyright (c) Orbis Technology 2001. All rights reserved.
  ------------------------------------------------------------------------
  Insert an Age Verification status reason

  ------------------------------------------------------------------------
}
drop procedure pInsVrfCustReason;

create procedure pInsVrfCustReason(
	p_adminuser        like tAdminUser.username,
	p_reason_code      like tVrfCustReason.reason_code,
	p_desc             like tVrfCustReason.desc,
	p_status           like tVrfCustReason.status
);

	-- $Id: pInsVrfCustReason.sql,v 1.1 2011/10/04 12:40:38 xbourgui Exp $

	define v_user_id int;

	-- check admin authorisation
	let v_user_id = pCheckAdminAuth(
		p_username = p_adminuser,
		p_action   = 'VrfAgeManage'
	);

	if p_reason_code == '' then
		raise exception -746,0,"Failed to insert into tAgeVrfReason - reason_code is empty";
	end if


	if exists (
		select
			reason_code
		from
			tVrfCustReason
		where
			reason_code = p_reason_code
	) then
		raise exception -746,0,"Reason code already exists.";
	end if


	insert into tVrfCustReason (
		reason_code,
		desc,
		status
	) values (
		p_reason_code,
		p_desc,
		p_status
	);

	if DBINFO('sqlca.sqlerrd2') <> 1 then
		raise exception -746,0,"Failed to insert into tAgeVrfReason";
	end if

end procedure;
