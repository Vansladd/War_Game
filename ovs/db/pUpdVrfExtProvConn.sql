{
------------------------------------------------------------------------
	Copyright (c) Orbis Technology 2001. All rights reserved.
------------------------------------------------------------------------
	Update a the order of checks in a verification profile definition
------------------------------------------------------------------------
}
drop procedure pUpdVrfExtProvConn;

create procedure pUpdVrfExtProvConn
	(
	p_vrf_ext_conn_id like tVrfExtProvConn.vrf_ext_conn_id,
	p_uri             like tVrfExtProvConn.uri      default null,
	p_action          like tVrfExtProvConn.action   default null,
	p_uname           like tVrfExtProvConn.uname    default null,
	p_password        like tVrfExtProvConn.password default null,
	p_status          like tVrfExtProvConn.status   default null,
	p_type            like tVrfExtProvConn.type     default null
	)

	define v_status   like tVrfExtProvConn.status;
	define v_type     like tVrfExtProvConn.type;
	define v_password like tVrfExtProvConn.password;

	--$Id: pUpdVrfExtProvConn.sql,v 1.1 2011/10/04 12:40:38 xbourgui Exp $
	
	select
		status,
		type,
		password
	into
		v_status,
		v_type,
		v_password
	from
		tVrfExtProvConn
	where
		vrf_ext_conn_id = p_vrf_ext_conn_id;

	if DBINFO('sqlca.sqlerrd2') <> 1 then
		raise exception -746, 0, "Cannot find details for external provider connection #" || p_vrf_ext_conn_id;
	end if

	-- put current values into inputs which are null

	let p_status   = NVL(p_status, v_status);
	let p_type     = NVL(p_type  , v_type);
	let p_password = NVL(p_password, v_password);

	update tVrfExtProvConn set
		uri      = p_uri,
		action   = p_action,
		uname    = p_uname,
		password = p_password,
		status   = p_status,
		type     = p_type
	where
		vrf_ext_conn_id = p_vrf_ext_conn_id;

	if DBINFO('sqlca.sqlerrd2') <> 1 then
		raise exception -746, 0, "Cannot find external provider connection #" || p_vrf_ext_conn_id;
	end if

	return;

end procedure;
