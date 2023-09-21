{
------------------------------------------------------------------------
	Copyright (c) Orbis Technology 2001. All rights reserved.
------------------------------------------------------------------------
	Update a the order of checks in a verification profile definition
------------------------------------------------------------------------
}
drop procedure pUpdVrfExtPrflDef;

create procedure pUpdVrfExtPrflDef
	(
	p_vrf_ext_pdef_id like tVrfExtPrflDef.vrf_ext_pdef_id,
	p_prov_prf_id     like tVrfExtPrflDef.prov_prf_id,
	p_description     like tVrfExtPrflDef.description,
	p_status          like tVrfExtPrflDef.status          default null
	)

	define v_status      like tVrfExtPrflDef.status;

	--$Id: pUpdVrfExtPrflDef.sql,v 1.1 2011/10/04 12:40:38 xbourgui Exp $
	
	select
		status
	into
		v_status
	from
		tVrfExtPrflDef
	where
		vrf_ext_pdef_id = p_vrf_ext_pdef_id;

	if DBINFO('sqlca.sqlerrd2') <> 1 then
		raise exception -746, 0, "Cannot find details for external profile #" || p_vrf_ext_pdef_id;
	end if

	-- put current values into inputs which are null
	let p_status      = NVL(p_status     , v_status);

	update tVrfExtPrflDef set
		prov_prf_id = p_prov_prf_id,
		description = p_description,
		status      = p_status
	where
		vrf_ext_pdef_id = p_vrf_ext_pdef_id;

	if DBINFO('sqlca.sqlerrd2') <> 1 then
		raise exception -746, 0, "Cannot find external profile #" || p_vrf_ext_pdef_id;
	end if

	return;

end procedure;
