{
------------------------------------------------------------------------
	Copyright (c) Orbis Technology 2001. All rights reserved.
------------------------------------------------------------------------
	Add a new check definition to a verification profile definition
------------------------------------------------------------------------
}
drop procedure pInsVrfChkDef;

create procedure pInsVrfChkDef
	(
	p_vrf_prfl_def_id like tVrfPrflDef.vrf_prfl_def_id,
	p_vrf_chk_type    like tVrfChkType.vrf_chk_type,
	p_channels        like tVrfChkDef.channels,
	p_check_no        like tVrfChkDef.check_no
	)
returning int;

	--$Id: pInsVrfChkDef.sql,v 1.1 2011/10/04 12:40:38 xbourgui Exp $

	define v_vrf_chk_def_id int;
	define v_vrf_chk_class  like tVrfChkType.vrf_chk_class;
	define v_vrf_chk_type   like tVrfChkType.vrf_chk_type;

	insert into tVrfChkDef
		(
		vrf_prfl_def_id,
		vrf_chk_type,
		channels,
		check_no
		)
	values
		(
		p_vrf_prfl_def_id,
		p_vrf_chk_type,
		p_channels,
		p_check_no
		);

	let v_vrf_chk_def_id = DBINFO('sqlca.sqlerrd1');

	select
		vrf_chk_class
	into
		v_vrf_chk_class
	from
		tVrfChkType
	where
		vrf_chk_type = p_vrf_chk_type;

	if v_vrf_chk_class = 'URU' OR v_vrf_chk_class = 'GEN' then

		-- Has to be done in the TCL
		return v_vrf_chk_def_id;

	elif v_vrf_chk_class = 'AUTH_PRO' then

		-- Has to be done in the TCL
		return v_vrf_chk_def_id;

	elif v_vrf_chk_class = 'IP' then

		execute procedure pInsVrfIPDef
			(
			p_vrf_chk_def_id = v_vrf_chk_def_id,
			p_vrf_chk_type = p_vrf_chk_type
			);

	elif v_vrf_chk_class = 'CARD' then

		if p_vrf_chk_type = 'OB_CARD_SCHEME' then

			execute procedure pInsVrfCardDef
				(
				p_vrf_chk_def_id = v_vrf_chk_def_id,
				p_vrf_chk_type = p_vrf_chk_type
				);
		end if;

	else
		raise exception -746,0,'Unrecognised Check Class';
	end if;

	return v_vrf_chk_def_id;

end procedure;
