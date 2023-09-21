{
------------------------------------------------------------------------
	Copyright (c) Orbis Technology 2001. All rights reserved.
------------------------------------------------------------------------
	Update a the order of checks in a verification profile definition
------------------------------------------------------------------------
}
drop procedure pUpdVrfChkOrder;

create procedure pUpdVrfChkOrder
	(
	p_vrf_chk_def_id  like tVrfChkDef.vrf_chk_def_id,
	p_check_no        like tVrfChkDef.check_no
	)

	define v_old_check_no    like tVrfChkDef.check_no;
	define v_old_chk_def_id  like tVrfChkDef.vrf_chk_def_id;
	define v_max_check_no    like tVrfChkDef.check_no;
	define v_vrf_prfl_def_id like tVrfPrflDef.vrf_prfl_def_id;

	--$Id: pUpdVrfChkOrder.sql,v 1.1 2011/10/04 12:40:38 xbourgui Exp $

	-- Find old check number of check definition we're updating
	select
		check_no,
		vrf_prfl_def_id
	into
		v_old_check_no,
		v_vrf_prfl_def_id
	from
		tVrfChkDef
	where
		vrf_chk_def_id = p_vrf_chk_def_id;

	-- If the old check order and the new check order don't match...
	if v_old_check_no != p_check_no then

		-- Find max check number
		select
			count(*)
		into
			v_max_check_no
		from
			tVrfChkDef
		where
			vrf_prfl_def_id = v_vrf_prfl_def_id;

		-- Find check definition currently set to order number p_check_no
		select
			vrf_chk_def_id
		into
			v_old_chk_def_id
		from
			tVrfChkDef
		where
			vrf_prfl_def_id = v_vrf_prfl_def_id
		and check_no = p_check_no;

		-- Move old check definition out of harms way
		update
			tVrfChkDef
		set
			check_no = v_max_check_no
		where
			vrf_chk_def_id = v_old_chk_def_id;

		-- Assign the p_check_no to the new check definition
		update
			tVrfChkDef
		set
			check_no = p_check_no
		where
			vrf_chk_def_id = p_vrf_chk_def_id;

		-- Move the old check definition to the newly vacated position
		update
			tVrfChkDef
		set
			check_no = v_old_check_no
		where
			vrf_chk_def_id = v_old_chk_def_id;
	end if;

end procedure;
