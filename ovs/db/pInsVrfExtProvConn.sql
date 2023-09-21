{
------------------------------------------------------------------------
	Copyright (c) Orbis Technology 2001. All rights reserved.
------------------------------------------------------------------------
	Add a new provider to the external providers list.
------------------------------------------------------------------------
}
drop procedure pInsVrfExtProvConn;

create procedure pInsVrfExtProvConn
	(
	p_vrf_ext_prov_id like tVrfExtProvConn.vrf_ext_prov_id,
	p_uri             like tVrfExtProvConn.uri,
	p_action          like tVrfExtProvConn.action,
	p_uname           like tVrfExtProvConn.uname,
	p_password        like tVrfExtProvConn.password,
	p_status          like tVrfExtProvConn.status,
	p_type            like tVrfExtProvConn.type
	)
returning int;

	define v_vrf_ext_conn_id like tVrfExtProvConn.vrf_ext_conn_id;

	--$Id: pInsVrfExtProvConn.sql,v 1.1 2011/10/04 12:40:38 xbourgui Exp $

	if NVL(p_status, '') not in ('A','S') then
		let p_status = 'S';
	end if
	if NVL(p_type, '') not in ('A','L','O') then
		let p_type = 'O';
	end if

	insert into tVrfExtProvConn
		(vrf_ext_prov_id, uri, action, uname, password, status, type)
	values
		(p_vrf_ext_prov_id, p_uri, p_action, p_uname, p_password, p_status, p_type);

	let v_vrf_ext_conn_id = DBINFO('sqlca.sqlerrd1');

	return v_vrf_ext_conn_id;

end procedure;