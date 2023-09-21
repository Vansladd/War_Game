{
------------------------------------------------------------------------
	Copyright (c) Orbis Technology 2001. All rights reserved.
------------------------------------------------------------------------
	Add a new provider to the external providers list.
------------------------------------------------------------------------
}
drop procedure pInsVrfExtProv;

create procedure pInsVrfExtProv
	(
	p_name           like tVrfExtProv.name,
	p_code           like tVrfExtProv.code,
	p_status         like tVrfExtProv.status,
	p_priority       like tVrfExtProv.priority
	)
returning int;

	define v_vrf_ext_prov_id like tVrfExtProv.vrf_ext_prov_id;

	--$Id: pInsVrfExtProv.sql,v 1.1 2011/10/04 12:40:38 xbourgui Exp $
	
	insert into tVrfExtProv
		(name, code, status, priority)
	values
		(p_name, p_code, p_status, p_priority);

	let v_vrf_ext_prov_id = DBINFO('sqlca.sqlerrd1');

	return v_vrf_ext_prov_id;

end procedure;