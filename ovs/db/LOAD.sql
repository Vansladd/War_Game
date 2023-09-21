begin;

!echo Loading into tAdminOpType
load from 'data/tAdminOpType.dat'
	insert into tAdminOpType
		(
		type,
		desc
		);

!echo Loading into tAdminOp
load from 'data/tAdminOp.dat'
	insert into tAdminOp
		(
		action,
		desc,
		type
		);

!echo Loading into tCustFlagDesc
load from 'data/tCustFlagDesc.dat'
	insert into tCustFlagDesc
		(
		flag_name,
		description
		);

!echo Loading into tCustFlagVal
load from 'data/tCustFlagVal.dat'
    insert into tCustFlagVal;

!echo Loading into tVrfPrflDef
load from 'data/tVrfPrflDef.dat'
	insert into tVrfPrflDef
		(
		vrf_prfl_def_id,
		vrf_prfl_code,
		status,
		desc,
		blurb,
		channels
		);

!echo Loading into tVrfPrflAct
load from 'data/tVrfPrflAct.dat'
	insert into tVrfPrflAct
		(
		vrf_prfl_act_id,
		vrf_prfl_def_id,
		action,
		high_score
		);

!echo Loading into tVrfPrflCty
load from 'data/tVrfPrflCty.dat'
	insert into tVrfPrflCty
		(
		vrf_prfl_def_id,
		country_code,
		status,
		grace_days
		);

!echo Loading into tVrfChkClass
load from 'data/tVrfChkClass.dat'
	insert into tVrfChkClass
		(
		vrf_chk_class,
		description
		);

!echo Loading into tVrfChkType
load from 'data/tVrfChkType.dat'
	insert into tVrfChkType
		(
		vrf_chk_type,
		description,
		vrf_chk_class,
		name
		);

!echo Loading into tVrfChkDef
load from 'data/tVrfChkDef.dat'
	insert into tVrfChkDef
		(
		vrf_chk_def_id,
		vrf_prfl_def_id,
		vrf_chk_type,
		status,
		channels,
		check_no
		);

!echo Loading into tVrfExtProv
load from 'data/tVrfExtProv.dat'
	insert into tVrfExtProv
		(
		vrf_ext_prov_id,
		name,
		code,
		status,
		priority
		);

!echo Loading into tVrfExtProvConn
load from 'data/tVrfExtProvConn.dat'
	insert into tVrfExtProvConn
		(
		vrf_ext_conn_id,
		vrf_ext_prov_id,
		uri,
		action,
		uname,
		password,
		status,
		type
		);

!echo Loading into tVrfExtPrflDef
load from 'data/tVrfExtPrflDef.dat'
	insert into tVrfExtPrflDef
		(
		vrf_ext_pdef_id,
		vrf_ext_prov_id,
		prov_prf_id,
		status,
		description
		);

!echo Loading into tVrfExtChkDef
load from 'data/tVrfExtChkDef.dat'
	insert into tVrfExtChkDef
		(
		vrf_ext_cdef_id,
		vrf_chk_type,
		vrf_ext_pdef_id,
		status
		);

!echo Loading into tVrfURUType
load from 'data/tVrfURUType.dat'
	insert into tVrfURUType
		(
		vrf_chk_type,
		response_no,
		response_type,
		description
		);

!echo Loading into tVrfURUDef
load from 'data/tVrfURUDef.dat'
	insert into tVrfURUDef
		(
		vrf_uru_def_id,
		vrf_chk_def_id,
		response_no,
		response_type,
		score,
		description
		);

!echo Loading into tVrfAuthProType
load from 'data/tVrfAuthProType.dat'
	insert into tVrfAuthProType
		(
		vrf_chk_type,
		response_no,
		response_type,
		description
		);

!echo Loading into tVrfAuthProDef
load from 'data/tVrfAuthProDef.dat'
	insert into tVrfAuthProDef
		(
		vrf_auth_pro_def_id,
		vrf_chk_def_id,
		response_no,
		response_type,
		score,
		description
		);

!echo Loading into tVrfGenType
load from 'data/tVrfGenType.dat'
	insert into tVrfGenType
		(
		vrf_chk_type,
		response_no,
		response_type,
		description
		);

!echo Loading into tVrfCustReason
load from 'data/tVrfCustReason.dat'
	insert into tVrfCustReason
		(
		reason_code,
		desc,
		status
		);

commit;
