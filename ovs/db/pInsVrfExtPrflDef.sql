{
------------------------------------------------------------------------
	Copyright (c) Orbis Technology 2001. All rights reserved.
------------------------------------------------------------------------
	Add a new provider to the external providers list.
------------------------------------------------------------------------
}
drop procedure pInsVrfExtPrflDef;

create procedure pInsVrfExtPrflDef
	(
	p_vrf_ext_prov_id like tVrfExtPrflDef.vrf_ext_prov_id,
	p_prov_prf_id     like tVrfExtPrflDef.prov_prf_id,
	p_description     like tVrfExtPrflDef.description,
	p_status          like tVrfExtPrflDef.status
	)
returning int;

	define v_vrf_ext_pdef_id like tVrfExtPrflDef.vrf_ext_pdef_id;

	--$Id: pInsVrfExtPrflDef.sql,v 1.1 2011/10/04 12:40:38 xbourgui Exp $
	
	insert into tVrfExtPrflDef
		(vrf_ext_prov_id, prov_prf_id, description, status)
	values
		(p_vrf_ext_prov_id, p_prov_prf_id, p_description, p_status);

	let v_vrf_ext_pdef_id = DBINFO('sqlca.sqlerrd1');

	return v_vrf_ext_pdef_id;

end procedure;