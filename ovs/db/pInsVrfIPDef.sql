{
------------------------------------------------------------------------
	Copyright (c) Orbis Technology 2001. All rights reserved.
------------------------------------------------------------------------
	Add a new IP check definition to a verification profile definition
------------------------------------------------------------------------
}
drop procedure pInsVrfIPDef;

create procedure pInsVrfIPDef
	(
	p_vrf_chk_def_id like tVrfChkDef.vrf_chk_def_id,
	p_vrf_chk_type   like tVrfChkType.vrf_chk_type
	)

	define v_country_code like tCountry.country_code;

	--$Id: pInsVrfIPDef.sql,v 1.1 2011/10/04 12:40:38 xbourgui Exp $

	if p_vrf_chk_type = "GEO_IP_LOCATION" then

		foreach
			select
				country_code
			into
				v_country_code
			from
				tCountry
			where
				status = "A"

			-- Response matches
			insert into tVrfIPDef
				(vrf_chk_def_id, country_code, response_type)
			values
				(p_vrf_chk_def_id, v_country_code, 'M');

			-- Response does not match
			insert into tVrfIPDef
				(vrf_chk_def_id, country_code, response_type)
			values
				(p_vrf_chk_def_id, v_country_code, 'N');

			-- Response is unknown
			insert into tVrfIPDef
				(vrf_chk_def_id, country_code, response_type)
			values
				(p_vrf_chk_def_id, v_country_code, 'U');

		end foreach;

	else

		raise exception -746,0,"Unrecognised IP Check";

	end if;

end procedure;