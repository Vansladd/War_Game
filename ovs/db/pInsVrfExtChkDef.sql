{
------------------------------------------------------------------------
	Copyright (c) Orbis Technology 2001. All rights reserved.
------------------------------------------------------------------------
	Add a new check to an external profile.
------------------------------------------------------------------------
}
drop procedure pInsVrfExtChkDef;

create procedure pInsVrfExtChkDef
	(
	p_vrf_chk_type    like tVrfExtChkDef.vrf_chk_type,
	p_vrf_ext_pdef_id like tVrfExtChkDef.vrf_ext_pdef_id
	)
returning int;

	define v_vrf_ext_cdef_id like tVrfExtChkDef.vrf_ext_cdef_id;

	--$Id: pInsVrfExtChkDef.sql,v 1.1 2011/10/04 12:40:38 xbourgui Exp $
	
	insert into tVrfExtChkDef
		(vrf_chk_type, vrf_ext_pdef_id)
	values
		(p_vrf_chk_type, p_vrf_ext_pdef_id);

	let v_vrf_ext_cdef_id = DBINFO('sqlca.sqlerrd1');

	return v_vrf_ext_cdef_id;

end procedure;
