{
------------------------------------------------------------------------
	Copyright (c) Orbis Technology 2001. All rights reserved.
------------------------------------------------------------------------
	Add a new generic test harness check definition to a verification
	profile definition
------------------------------------------------------------------------
}
drop procedure pInsVrfGenDef;

create procedure pInsVrfGenDef
	(
	p_vrf_chk_def_id like tVrfChkDef.vrf_chk_def_id,
	p_response_no    like tVrfGenDef.response_no,
	p_response_type  like tVrfGenDef.response_type,
	p_description    like tVrfGenDef.description
	)
returning int;

	define v_vrf_gen_def_id like tVrfGenDef.vrf_gen_def_id;

	--$Id: pInsVrfGenDef.sql,v 1.1 2011/10/04 12:40:38 xbourgui Exp $

	insert into tVrfGenDef
		(vrf_chk_def_id, response_no, response_type, description)
	values
		(p_vrf_chk_def_id, p_response_no, p_response_type, p_description);


	let v_vrf_gen_def_id = DBINFO('sqlca.sqlerrd1');

	return v_vrf_gen_def_id;

end procedure;
