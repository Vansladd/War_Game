{
  ------------------------------------------------------------------------
  Copyright (c) Orbis Technology 2008. All rights reserved.
  ------------------------------------------------------------------------
  Set a customers Age Verification status

  ------------------------------------------------------------------------
}
drop procedure pUpdAgeVrfCust;

create procedure pUpdAgeVrfCust(
	p_cust_id        like tAgeVrfCust.cust_id,
	p_status         like tAgeVrfCust.status,
	p_reason_code    like tAgeVrfCust.reason_code   default null

);

	-- $Id: pUpdAgeVrfCust.sql,v 1.1 2011/10/04 12:40:38 xbourgui Exp $

	if exists (
		select
			status
		from
			tAgeVrfCust
		where
		    cust_id = p_cust_id
	) then

		update tAgeVrfCust set
			status = p_status
		where
		    cust_id = p_cust_id;

	else

		insert into tAgeVrfCust(
			status,
			reason_code,
			cust_id)
		values (
			p_status,
			p_reason_code,
			p_cust_id
		);
	end if;

	if DBINFO('sqlca.sqlerrd2') <> 1 then
		raise exception -746,0,"Failed to insert/update tAgeVrfCust";
	end if;

end procedure;
