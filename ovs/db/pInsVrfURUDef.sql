{
------------------------------------------------------------------------
	Copyright (c) Orbis Technology 2001. All rights reserved.
------------------------------------------------------------------------
	Add a new Authenticate Pro check definition to a verification profile
	definition
------------------------------------------------------------------------
}
drop procedure pInsVrfAuthProDef;

create procedure pInsVrfAuthProDef
	(
	p_vrf_chk_def_id like tVrfChkDef.vrf_chk_def_id,
	p_response_no    like tVrfAuthProDef.response_no,
	p_response_type  like tVrfAuthProDef.response_type,
	p_description    like tVrfAuthProDef.description
	)
returning int;

	define v_vrf_auth_pro_def_id like tVrfAuthProDef.vrf_auth_pro_def_id;

	--$Id: pInsVrfURUDef.sql,v 1.1 2011/10/04 12:40:38 xbourgui Exp $

	insert into tVrfAuthProDef (
		vrf_chk_def_id,
		response_no,
		response_type,
		description
	) VALUES (
		p_vrf_chk_def_id,
		p_response_no,
		p_response_type,
		p_description
	);

	let v_vrf_auth_pro_def_id = DBINFO('sqlca.sqlerrd1');

	return v_vrf_auth_pro_def_id;

end procedure;
