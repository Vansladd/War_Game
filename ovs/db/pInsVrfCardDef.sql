{
------------------------------------------------------------------------
	Copyright (c) Orbis Technology 2001. All rights reserved.
------------------------------------------------------------------------
	Add a new card check definition to a verification profile definition
------------------------------------------------------------------------
}
drop procedure pInsVrfCardDef;

create procedure pInsVrfCardDef
	(
	p_vrf_chk_def_id like tVrfChkDef.vrf_chk_def_id,
	p_vrf_chk_type   like tVrfChkType.vrf_chk_type
	)

	define v_scheme like tCardSchemeInfo.scheme;

	--$Id: pInsVrfCardDef.sql,v 1.1 2011/10/04 12:40:38 xbourgui Exp $

	if p_vrf_chk_type = 'OB_CARD_SCHEME' then

		foreach
			select
				scheme
			into
				v_scheme
			from
				tCardSchemeInfo

			insert into tVrfCardDef
				(vrf_chk_def_id, scheme)
			values
				(p_vrf_chk_def_id, v_scheme);

		end foreach;

	else
		raise exception -746,0,"Unrecognised Card Check";

	end if;

end procedure;
