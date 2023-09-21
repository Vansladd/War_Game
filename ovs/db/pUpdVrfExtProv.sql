{
------------------------------------------------------------------------
	Copyright (c) Orbis Technology 2001. All rights reserved.
------------------------------------------------------------------------
	Update a the order of checks in a verification profile definition
------------------------------------------------------------------------
}
drop procedure pUpdVrfExtProv;

create procedure pUpdVrfExtProv
	(
	p_vrf_ext_prov_id like tVrfExtProv.vrf_ext_prov_id,
	p_name            like tVrfExtProv.name            default null,
	p_code            like tVrfExtProv.code            default null,
	p_status          like tVrfExtProv.status          default null,
	p_priority        like tVrfExtProv.priority        default null
	)

	define v_name     like tVrfExtProv.name;
	define V_code     like tVrfExtProv.code;
	define v_status   like tVrfExtProv.status;
	define v_priority like tVrfExtProv.priority;

	--$Id: pUpdVrfExtProv.sql,v 1.1 2011/10/04 12:40:38 xbourgui Exp $
	
	select
		name,
		code,
		status,
		priority
	into
		v_name,
		v_code,
		v_status,
		v_priority
	from
		tVrfExtProv
	where
		vrf_ext_prov_id = p_vrf_ext_prov_id;

	if DBINFO('sqlca.sqlerrd2') <> 1 then
		raise exception -746, 0, "Cannot find details for external provider #" || p_vrf_ext_prov_id;
	end if

	-- put current values into inputs which are null

	let p_name     = NVL(p_name    , v_name);
	let p_code     = NVL(p_code    , v_code);
	let p_status   = NVL(p_status  , v_status);
	let p_priority = NVL(p_priority, v_priority);

	update tVrfExtProv set
		name     = p_name,
		code     = p_code,
		status   = p_status,
		priority = p_priority
	where
		vrf_ext_prov_id = p_vrf_ext_prov_id;

	if DBINFO('sqlca.sqlerrd2') <> 1 then
		raise exception -746, 0, "Cannot find external provider #" || p_vrf_ext_prov_id;
	end if

	return;

end procedure;
