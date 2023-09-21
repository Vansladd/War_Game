{
  ------------------------------------------------------------------------
  Copyright (c) Orbis Technology 2008. All rights reserved.
  ------------------------------------------------------------------------
  Set a customers Age Verification status

  ------------------------------------------------------------------------
}

drop procedure pUpdVrfCustStatus;
create procedure pUpdVrfCustStatus (
	p_adminuser      like tAdminUser.username,
	p_cust_id        like tVrfCustStatus.cust_id,
	p_status         like tVrfCustStatus.status,
	p_reason_code    like tVrfCustStatus.reason_code       default null,
	p_notes          like tVrfCustStatus.notes             default null,
	p_vrf_prfl_code  like tVrfPrflDef.vrf_prfl_code,
	p_transactional  char(1) default 'Y',
	p_prfl_model_id  like tVrfPrflModel.vrf_prfl_model_id  default null
);
	define v_cust_flag_id      like tCustStatusFlag.cust_flag_id;
	define v_status_flag_tag_s like tCustStatusFlag.status_flag_tag;
	define v_status_flag_tag_p like tCustStatusFlag.status_flag_tag;
	define v_cust_status       like tCustomer.status;
	define v_vrf_cust_status   like tVrfCustStatus.status;
	define v_bet_id            like tBet.bet_id;
	define v_user_id           like tBet.bet_id;
	define v_expiry_date       like tVrfCustStatus.expiry_date;
	define v_pay_mthd          like tVrfPrflModel.pay_mthd;
	define v_type              like tVrfPrflModel.type;
	define v_dummy             smallint;
	define v_notes             like tVrfCustStatus.notes;

	-- Transaction variables.
	define err_code       int;
	define err_isam       int;
	define err_msg        varchar(255);

	-- $Id: pUpdVrfCustStatus.sql,v 1.1 2011/10/04 12:40:38 xbourgui Exp $

	-- Begin the transaction.
	on exception set err_code, err_isam, err_msg
		if p_transactional == 'Y' then
			rollback work;
		end if
		raise exception err_code,err_isam,err_msg;
	end exception

	--set debug file to '/tmp/pUpdVrfCustStatusA.log';
	--trace on;

	if (nvl(p_transactional,'') not in ('Y','N')) then
		let p_transactional = 'Y';
	end if

	if p_transactional == 'Y' then
		begin work;
	end if

	let v_expiry_date = "9999-12-31 00:00:00";

	-- Grab the user id.
	select
		user_id
	into
		v_user_id
	from
		tAdminUser
	where
		username = p_adminuser;


	--
	-- If customer isn't suspendend then suspend the customer.
	--
	let v_status_flag_tag_p = "OVS_"||p_vrf_prfl_code||"_P";
	let v_status_flag_tag_s = "OVS_"||p_vrf_prfl_code||"_S";
	let v_cust_flag_id = null;

	if (p_status == 'P') then
		if p_prfl_model_id is not null then
			-- pmt mthd provided, grab grace from the prfl model table.
			select
				current + pm.grace_days UNITS DAY
			into
				v_expiry_date
			from
				tVrfPrflDef   pd,
				tVrfPrflModel pm,
				tVrfPrflCty   pc,
				tCustomer     c
			where			    
				    c.cust_id            = p_cust_id
				and pc.country_code      = c.country_code
				and pc.country_code      = pm.country_code
				and pc.vrf_prfl_def_id   = pd.vrf_prfl_def_id
				and pc.country_code      = pm.country_code
				and pm.vrf_prfl_def_id   = pd.vrf_prfl_def_id
				and pm.vrf_prfl_model_id = p_prfl_model_id
				and pd.vrf_prfl_code     = p_vrf_prfl_code;
		else
			-- No pmt mthd provided, grab grace from the country table
			select
				current + pc.grace_days UNITS DAY
			into
				v_expiry_date
			from
				tVrfPrflDef   pd,
				tVrfPrflCty   pc,
				tCustomer     c
			where			    
				    c.cust_id          = p_cust_id
				and pc.country_code    = c.country_code
				and pd.vrf_prfl_def_id = pc.vrf_prfl_def_id
				and pd.vrf_prfl_code   = p_vrf_prfl_code;
		end if
		
		if (v_expiry_date is null) then
			let v_expiry_date = "9999-12-31 00:00:00";
		end if

		select
			cust_flag_id
		into
			v_cust_flag_id
		from
			tCustStatusFlag
		where
			cust_id = p_cust_id
			and status_flag_tag = v_status_flag_tag_s
			and status          = 'A';
			
		if v_cust_flag_id is not null then
			-- clear S
			execute procedure pUpdCustStatusFlag (
				p_cust_flag_id    = v_cust_flag_id,
				p_user_id         = v_user_id,
				p_transactional   = 'N'
			);
		end if

		if not exists (
			select
				*
			from
				tVrfCustStatus
			where
				    cust_id       = p_cust_id
				and vrf_prfl_code = v_status_flag_tag_p
		) then
			-- Insert a customer status flag.
			let v_cust_flag_id = pInsCustStatusFlag (
				p_cust_id         = p_cust_id,
				p_status_flag_tag = v_status_flag_tag_p,
				p_user_id         = v_user_id,
				p_reason          = "Reason stored in tVrfCustStatus",
				p_transactional   = 'N'
			);
		end if
	elif p_status == 'S' or p_status == 'U' then
		select
			cust_flag_id
		into
			v_cust_flag_id
		from
			tCustStatusFlag
		where
				cust_id = p_cust_id
			and status_flag_tag = v_status_flag_tag_p
			and status          = 'A';

		if v_cust_flag_id is not null  then
			-- clear P
			execute procedure pUpdCustStatusFlag (
				p_cust_flag_id    = v_cust_flag_id,
				p_user_id         = v_user_id,
				p_transactional   = 'N'
			);
		
		end if
		
		if not exists (
			select
				*
			from
				tVrfCustStatus
			where
				    cust_id       = p_cust_id
				and vrf_prfl_code = v_status_flag_tag_p
		) then
			-- Insert a customer status flag.
			let v_cust_flag_id = pInsCustStatusFlag (
				p_cust_id         = p_cust_id,
				p_status_flag_tag = v_status_flag_tag_s,
				p_user_id         = v_user_id,
				p_reason          = "Reason stored in tVrfCustStatus",
				p_transactional   = 'N'
			);
		end if
	elif p_status = 'A' then
		foreach
			select
				cust_flag_id
			into
				v_cust_flag_id
			from
				tCustStatusFlag
			where
				cust_id = p_cust_id
			and (status_flag_tag = v_status_flag_tag_s
			or  status_flag_tag = v_status_flag_tag_p)
			and status          = 'A'

			-- clear flags
			execute procedure pUpdCustStatusFlag (
				p_cust_flag_id    = v_cust_flag_id,
				p_user_id         = v_user_id,
				p_transactional   = 'N'
			);

		end foreach;
	end if




	--
	-- Update tVrfCustStatus
	--

	if exists (
		select
			*
		from
			tVrfCustStatus
		where
		        cust_id       = p_cust_id
			and vrf_prfl_code = p_vrf_prfl_code
	) then

		if p_notes is not null then
			let v_notes = p_notes;
		else
			select
				notes
			into
				v_notes
			from
				tVrfCustStatus
			where
				cust_id       = p_cust_id
				and vrf_prfl_code = p_vrf_prfl_code;
		end if

		-- Update
		update tVrfCustStatus set
			reason_code  = p_reason_code,
			notes        = v_notes,
			status       = p_status,
			cust_flag_id = v_cust_flag_id,
			expiry_date  = v_expiry_date
		where
		        cust_id       = p_cust_id
			and vrf_prfl_code = p_vrf_prfl_code;

		let v_vrf_cust_status = DBINFO('sqlca.sqlerrd1');
	else
		insert into tVrfCustStatus(
			reason_code,
			cust_id,
			vrf_prfl_code,
			status,
			notes,
			cust_flag_id,
			expiry_date
		) values (
			p_reason_code,
			p_cust_id,
			p_vrf_prfl_code,
			p_status,
			p_notes,
			v_cust_flag_id,
			v_expiry_date
		);

		let v_vrf_cust_status = DBINFO('sqlca.sqlerrd1');
	end if;

	if DBINFO('sqlca.sqlerrd2') <> 1 then
		raise exception -746,0,"Failed to insert/update tVrfCustStatus";
	end if;


	--
	-- If the customer is underage then cancel all bets.
	--
	if p_status == 'U' then

		foreach select
			b.bet_id
		into
			v_bet_id
		from
			tBet b,
			tAcct a
		where
			    a.cust_id = p_cust_id
			and a.acct_id = b.acct_id
			and b.settled = 'N'

			-- Cancel bet.
			let v_dummy = pSettleBet(
				p_adminuser      = p_adminuser,
				p_op             = 'X',
				p_bet_id         = v_bet_id,
				p_num_lines_win  = 0,
				p_num_lines_lose = 0,
				p_num_lines_void = 0,
				p_winnings       = null,
				p_tax            = 0,
				p_refund         = null,
				p_settled_how    = 'M',
				p_transactional  = 'N'
			);

		end foreach
	end if

	-- Commit!
	if p_transactional = 'Y' then
		commit work;
	end if

end procedure;
