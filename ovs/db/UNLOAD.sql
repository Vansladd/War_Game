!echo Unloading from tAdminOpType
unload to 'data/tAdminOpType.dat'
	select
		type,
		desc
	from tAdminOpType
	where type = 'VRF';

!echo Unloading from tAdminOp
unload to 'data/tAdminOp.dat'
	select
		action,
		desc,
		type
	from tAdminOp
	where type = 'VRF';

!echo Unloading from tVrfChkType
unload to 'data/tVrfChkType.dat'
	select
		vrf_chk_type,
		description,
		vrf_chk_class,
		name
	from tVrfChkType;

!echo Unloading from tVrfURUType
unload to 'data/tVrfURUType.dat'
	select
		vrf_chk_type,
		response_no,
		response_type,
		description
	from tVrfURUType;

!echo Unloading from tVrfGenType
unload to 'data/tVrfGenType.dat'
	select
		vrf_chk_type,
		response_no,
		response_type,
		description
	from tVrfGenType;
