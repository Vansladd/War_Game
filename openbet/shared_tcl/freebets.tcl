# ==============================================================
# $Id: freebets.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================


namespace eval OB_freebets {

	namespace export check_trigger
	namespace export init_freebets
	namespace export check_action
	namespace export get_cust_freebets
	namespace export tokens_for_bet
	namespace export redeem_tokens
	namespace export validate_tokens
	namespace export redeem_voucher
	namespace export check_referral

	variable log_name
	variable TRIGGER_FULFILLED

	global TOKENS
}

# ======================================================================
# Freebets, one time initialisation functions
# init_freebets should be called before any other function in this file
# ----------------------------------------------------------------------

proc OB_freebets::prep_freebets_qrys {} {

	global SHARED_SQL

	set cust_code_where ""

	if { [OT_CfgGet ENABLE_CUST_CODE 1 ] } {
			set cust_code_where {

				and cr.code in (
					select
						oc.cust_code
					from
						tOfferCustCode oc
					where
						oc.offer_id = o.offer_id
			)
		}
	}


	set fb_offers_qry {
		select
		    o.offer_id offer_id,
			o.max_claims max_claims,
		    o.unlimited_claims,
		    t.type_code,
			t.trigger_id trigger_id,
		    ct.called_trigger_id,
			t.rank	rank,
			t.text	char,
			ta.amount float,
			y.qualification	qualification,
			t.promo_code
		from
		    tTrigger       t,
		    outer tCalledTrigger ct,
		    tTriggerAmount ta,
		    tOffer         o,
		    tTriggerType   y,
		    tCustomer      c,
		    tAcct          a,
		    tCustomerReg   cr
		where 	o.start_date <= ?
		and     (o.end_date is null or o.end_date > ?)
		and
		(
		    (o.entry_expiry_date is null or o.entry_expiry_date > ?)
			or
			(exists
				(select
					1
				 from
					tCalledTrigger  ct2,
					tTrigger t2
				 where
					t2.offer_id     = o.offer_id    and
					ct2.trigger_id  = t2.trigger_id and
					ct2.status      = 'A'           and
					ct2.cust_id     = ?
				)
			)
		)
		and
		(
		    o.unlimited_claims = 'Y'
			or
			(o.max_claims >
			(	select	count(co.offer_id)
				from 	tClaimedOffer co
				where	co.cust_id = ? and
						co.offer_id = o.offer_id
			))
		)
		and	t.offer_id = o.offer_id
		and	t.type_code = y.type_code
		and t.trigger_id = ct.trigger_id
		and ct.cust_id = c.cust_id
		and cr.cust_id = c.cust_id
		and	t.type_code in (?,?,?,?,?,?)
		and (
			 o.channels like ?  or o.channels is null
		)
		and c.cust_id = a.cust_id
		and c.cust_id = ?
		and a.ccy_code   = ta.ccy_code
		and t.trigger_id = ta.trigger_id
		and (
			 o.country_code is null or
			 o.country_code like '%'||c.country_code||'%'
		)
		and NVL(o.lang,c.lang) = c.lang
		$cust_code_where
		and (
			c.elite = o.elite_only
			or o.elite_only = 'N'
		)
		order by 1,3,4,5
	}

	# Get a list of offers that may fulfull a trigger
	set SHARED_SQL(fb_offers) [subst $fb_offers_qry]

	set SHARED_SQL(fb_earlier_trigs) {
		execute procedure pEarlierTriggers (
			  p_offer_id = ?
			, p_trigger_id = ?
			, p_cust_id = ?
			, p_rank = ?
			);
	}

	set SHARED_SQL(fb_get_valid_aff) {
		select 	a.aff_id
		from 	taffiliate a
		where	a.aff_id = ?
	}

	set SHARED_SQL(fb_get_aff_grp) {
		select	a.aff_grp_id
		from 	taffiliate a
		where 	a.aff_id = ?
	}

	# query to get cust_id given username

	set SHARED_SQL(fb_ref_get_cust_id) {
		select
			cust_id
		from
			tcustomer
		where
			username = ?
	}

	# query to get cust_id given account number

	set SHARED_SQL(fb_ref_get_cust_id_acc) {
		select
			cust_id
		from
			tcustomer
		where
			acct_no = ?
	}

	set SHARED_SQL(fb_trigger_details) {
		select
			a.amount              as float,
			t.text                as char,
			t.aff_level,
			t.aff_id,
			t.aff_grp_id,
			t.voucher_type,
			t.channel_strict,
			t.buy_m,
			t.offer_id,
			UPPER(t.promo_code)  as promo_code
		from
			tTrigger              t,
			tTriggerAmount        a
		where
			t.trigger_id          = ?
		and t.trigger_id          = a.trigger_id
		and a.ccy_code            = ?
	}
	# superceeds tTriggerLevelId
	set SHARED_SQL(fb_trigger_levels) {
		select
			level,
			id
		from
			tTriggerLevel
		where
			trigger_id = ?
		order by
			1
	}
	set SHARED_SQL(cache,fb_trigger_levels) 600


	# find out if trigger has been claimed
	set SHARED_SQL(fb_has_claimed_trigger) {
		select first 1
			1
		from
			tCalledTrigger
		where
			trigger_id = ?
		and cust_id   = ?
		and status    = 'C'
	}

	set SHARED_SQL(fb_create_called_trigger) {
		execute procedure pInsCalledTrigger (
			p_offer_id = ?,
			p_trigger_id = ?,
			p_cust_id = ?,
			p_rank = ?,
			p_called_date = CURRENT,
			p_value = ?
			);
	}

	set SHARED_SQL(fb_create_claimed_offer) {
		execute procedure pInsClaimedOffer (
			p_offer_id = ?,
			p_cust_id = ?,
			p_claim_date = CURRENT
			);
	}

	set SHARED_SQL(fb_create_cust_tokens) {
		execute procedure pCreateCustTokens (
			p_claimed_offer = ?,
			p_cust_id 		= ?,
			p_called_trig_id= ?,
			p_ref_id        = ?,
			p_ref_type      = ?
			);
	}

	set SHARED_SQL(fb_claim_called_triggers) {
		execute procedure pClmCalledTriggers (
			p_offer_id = ?,
			p_cust_id = ?
			);
	}

	set SHARED_SQL(fb_outstanding_triggers) {
		select	t.trigger_id
		from 	tTrigger t,
				tOffer o
		where	o.offer_id = ? and
				o.offer_id = t.offer_id and
				t.trigger_id not in (
					select	trigger_id
					from	tCalledTrigger
					where	cust_id = ? and
							status = 'A'
				)
	}

	set SHARED_SQL(fb_called_triggers) {
		select
			c.trigger_id
		from
			tCalledTrigger c
		where
			c.trigger_id = ?
			and c.cust_id    = ?;
	}

	set SHARED_SQL(fb_basic_trigger) {
		select
			t.offer_id,
			t.type_code,
			t.rank,
			l.level as bet_level
		from
			tTrigger t,
			outer tTriggerLevel l
		where
			t.trigger_id = ?
			and t.trigger_id = l.trigger_id;
	}

	set SHARED_SQL(fb_check_for_referee) {
		select
			type_code
		from tTrigger
		where offer_id  = ?
		  and type_code = 'REFEREE'

	}

	set SHARED_SQL(fb_get_referral_cust) {
		select flag_value
	    from tCustomerFlag
		where cust_id   = ?
		  and flag_name = 'REF_CUST_ID'
	}

	set SHARED_SQL(fb_get_referral_aff) {
		select	aff_id
		from	tcustomer
		where	cust_id =?
	}

	set SHARED_SQL(fb_get_referral_offer) {
		select
			offer_id,
			trigger_id
		from ttrigger
		where type_code = 'REFERRAL'
		  and offer_id in (
			select
				ref_offer_id
			from ttrigger
			where type_code = 'REFEREE'
			  and offer_id = ?
		  )
	}

	set fb_cust_offers_sql {
			select
		    o.offer_id offer_id,
			o.name name,
			o.end_date end_date,
			o.description description
		from
		    tOffer    o,
		    tOfferCcy oc,
		    tCustomer cu,
		    tAcct     a,
		    tCustomerreg cr
		where
		    o.start_date <= CURRENT
		and
		    a.ccy_code  = oc.ccy_code
		and
		    oc.offer_id = o.offer_id
		and
		    cu.cust_id     =    ?
		and
		    a.cust_id      =    cu.cust_id
		and
		    cr.cust_id     =    cu.cust_id
		and
			NVL(o.country_code,cu.country_code) = cu.country_code
		and
			NVL(o.lang,cu.lang) = cu.lang
		and (
			    o.channels    like ?    or 	o.channels   is   null
			)
		and	(
				o.end_date is null or
				o.end_date > CURRENT
			)
		and	not exists (
				select	c.offer_id
				from	tClaimedOffer c
				where	c.offer_id = o.offer_id
				and	    c.cust_id = ?
			)
		and	(
				o.need_qualification='N' or
				not exists (
					select
					    t.trigger_id
					from
					    tTrigger t,
						tTriggerType y
					where
					    o.offer_id = t.offer_id
					and
					    t.type_code = y.type_code
					and
					    y.qualification = 'Y'
					and not exists (
						select	l.trigger_id
						from	tCalledTrigger l
						where	l.trigger_id = t.trigger_id
						and	l.cust_id = ?
					)
				)
			)
		and exists (
					select 1 from ttrigger
					where offer_id = o.offer_id
					and
					(aff_level is null
					or
					(aff_level = 'All'    and ? != '')
					or
					(aff_level = 'None'   and ? = '')
					or
					(aff_level = 'Single' and aff_id = ?)
					or
					(aff_level = 'Group' and
					 aff_grp_id in (select aff_grp_id
									from taffiliategrp
									where aff_id = ?)))
					)
			$cust_code_where 
		and (
			cu.elite = o.elite_only
			or o.elite_only = 'N'
		)
		order by end_date
	}

	# These two queries assume that any affiliates with ids < 0 are the
	# main site, and are lumped together. Aff_id parameters of 0 are
	# taken to be the main site.
	set SHARED_SQL(fb_cust_offers) [subst $fb_cust_offers_sql]


	# Get all the SPORTS tokens that the customer can currently use
	# The customertoken status must be 'A' for the customer to use it
	# This means checking  channel, currency, lang and country for the
	# customer against the token and its associated offer.
	#
	# Second query in the union returns ad hoc tokens also.
	set SHARED_SQL(fb_cust_tokens) {
		select
			ct.cust_token_id,
			ct.value,
			ct.adhoc_redemp_id,
			t.token_id,
			o.name as offer_name,
			o.offer_id as offer_id,
			ct.creation_date as creation_date,
			ct.expiry_date,
			to_char(ct.expiry_date, '%d/%m/%y') as short_expiry_date,
			rv.name,
			rv.redemption_id,
			rv.bet_level,
			rv.bet_type,
			rv.bet_id
		from
			tCustomerToken  ct,
			tToken          t,
			tTokenAmount    ta,
			tOffer          o,
			tPossibleBet    pb,
			tRedemptionVal  rv,
			tAcct           a,
			tCustomer       c
		where
			ct.cust_id       = ? and
			ct.token_id      = t.token_id and
			t.token_id       = ta.token_id and
			t.offer_id       = o.offer_id and
			t.token_type     = 'SPORTS' and
			pb.token_id      = t.token_id and
			rv.redemption_id = pb.redemption_id and
			a.cust_id        = ct.cust_id and
			ta.ccy_code      = a.ccy_code and
			c.cust_id        = ct.cust_id and
			NVL(o.lang,c.lang) = c.lang and
			NVL(o.country_code,c.country_code) = c.country_code and
			ct.redeemed      = 'N' and
			ct.status        = 'A' and
			ct.expiry_date   > CURRENT

		union

		select
			ct.cust_token_id,
			ct.value,
			ct.adhoc_redemp_id,
			t.token_id,
			o.name as offer_name,
			o.offer_id as offer_id,
			ct.creation_date as creation_date,
			ct.expiry_date,
			to_char(ct.expiry_date, '%d/%m/%y') as short_expiry_date,
			rv.name,
			rv.redemption_id,
			rv.bet_level,
			rv.bet_type,
			rv.bet_id
		from
			tCustomerToken  ct,
			tToken          t,
			tTokenAmount    ta,
			tOffer          o,
			tRedemptionVal  rv,
			tAcct           a,
			tCustomer       c
		where
			ct.cust_id       = ? and
			ct.token_id      = t.token_id and
			t.token_id       = ta.token_id and
			t.offer_id       = o.offer_id and
			t.token_type     = 'SPORTS' and
			a.cust_id        = ct.cust_id and
			ta.ccy_code      = a.ccy_code and
			c.cust_id        = ct.cust_id and
			NVL(o.lang,c.lang) = c.lang and
			NVL(o.country_code,c.country_code) = c.country_code and
			ct.redeemed      = 'N' and
			ct.status        = 'A' and
			ct.expiry_date   > CURRENT and
			ct.adhoc_redemp_id is not null and
			ct.adhoc_redemp_id = rv.redemption_id

		order by ct.cust_token_id, ct.expiry_date, rv.name
	}


	set SHARED_SQL(fb_gp_get_freebet_tokens_SNG) {
		select
			ct.cust_token_id,
			ct.value,
			ct.expiry_date,
			t.offer_id,
			t.single_use,
			gl.gp_game_id,
			g.ug_type_grp_code,
			l.min_stake,
			l.max_stake
		from
			tCustomerToken     ct,
			tToken             t,
			tGpgameGrpLk       gl,
			tGPGame            g,
			tGPTokGameLim      l,
			tAcct              a
		where
		    ct.cust_id         = ?
		and a.cust_id          = ct.cust_id
		and ct.redeemed        != 'Y'
		and ct.status          != 'X'
		and ct.expiry_date     >= current
		and ct.token_id        = t.token_id
		and l.token_id         = ct.token_id
		and l.gp_game_id       = g.gp_game_id
		and l.ccy_code         = a.ccy_code
		and t.gp_game_grp_id   = gl.gp_game_grp_id
		and gl.gp_game_id      = g.gp_game_id
		and g.system_arch      = 'SNG'
		order by
			ct.cust_token_id,
			g.ug_type_grp_code;
	}

	# Get all tokens which can be used for the current bet
	# the second half of the union returns adhoc freebets
	set SHARED_SQL(fb_bet_tokens) {
		select
			o.name           offer_name,
			tok.token_id     token_id,
			ct.value         value,
			ct.cust_token_id cust_token_id,
			ct.creation_date creation_date,
			ct.expiry_date   expiry_date
		from
			tOffer         o,
			tToken         tok,
			tTokenAmount   ta,
			tCustomerToken ct,
			tCustomer      c,
			tAcct          a
		where
			o.offer_id = tok.offer_id
		and	ct.redeemed = 'N'
		and	ct.status   = 'A'
		and	ct.expiry_date > CURRENT
		and	ct.cust_id = ?
		and	tok.token_id = ct.token_id
		and	tok.token_type = 'SPORTS'
		and	ct.cust_id   = c.cust_id
		and	c.cust_id    = a.cust_id
		and	ta.token_id = tok.token_id
		and	a.ccy_code  = ta.ccy_code
		and	NVL(o.lang,c.lang) = c.lang
		and	NVL(o.country_code,c.country_code) = c.country_code
		and	exists
		(
			select
				r.redemption_id
			from
				tRedemptionVal r
			where
				(r.redemption_id = ct.adhoc_redemp_id

				or

				r.redemption_id in (
									select
										redem.redemption_id
									from
										tPossibleBet poss,
										tRedemptionVal redem
									where
										tok.token_id = poss.token_id and
										poss.redemption_id = redem.redemption_id)) and
				(
				r.bet_level = 'ANY' or
				(
					"XGAME" = ? and
					r.bet_level = "XGAME" and
					(
						(
							r.bet_id is not null and
					 		r.bet_id  in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
						) or
						(
							r.bet_id is null and
							(
								(
									r.bet_type is not null and
									r.bet_type in
									(
										select	sort
										from	tXGame
										where	xgame_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
									)
								) or
								r.bet_type is null
							)
						)
					)
				) or
				(
					"SPORTS" = ? and
					(
						(
							r.bet_level = "SELECTION" and
							(
								r.bet_id is not null and
								r.bet_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
							)
						) or
						(
							r.bet_level = "EVENT" and
							(
								r.bet_id is not null and
								r.bet_id in
								(
									select	o.ev_id
									from    tEvOc o
									where	o.ev_oc_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
								)
							) or
							(
								r.bet_id is null and
								r.bet_type is not null and
								r.bet_type in
								(
									select	sort
									from	  tEv e
										, tEvOc o

									where	e.ev_id = o.ev_id and
										o.ev_oc_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
								)
							)
						) or
						(
							r.bet_level = "MARKET" and
							(
								r.bet_id is not null and
								r.bet_id in
								(
									select	o.ev_mkt_id
									from    tEvOc o
									where	o.ev_oc_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
								)
							) or
							(
								r.bet_id is null and
								r.bet_type is not null and
								r.bet_type in
								(
									select	sort
									from	  tEvMkt m
										, tEvOc o

									where	m.ev_mkt_id = o.ev_mkt_id and
										o.ev_oc_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
								)
							)
						) or
						(
							r.bet_level = "TYPE" and
							(
								r.bet_id is not null and
								r.bet_id in
								(
									select  t.ev_type_id
									from      tEvType t
        									, tEv e
                								, tEvOc o
        								where 	e.ev_type_id = t.ev_type_id and
										e.ev_id = o.ev_id and
										o.ev_oc_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
								)
							)
						) or
						(
							r.bet_level = "COUPON" and
							(
								r.bet_id is not null and
								r.bet_id in
								(
									select	  coupon_id
									from	  tCouponmkt cm
										, tEvMkt m
										, tEvOc o
									where	cm.ev_mkt_id = m.ev_mkt_id and
										m.ev_mkt_id = o.ev_mkt_id and
										o.ev_oc_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
								)
							)
						) or
						(
							r.bet_level = "CLASS" and
							(
								r.bet_id is not null and
								r.bet_id in
								(
									select	  et.ev_class_id
									from	  tEvType et
										, tEv e
										, tEvOc o
									where	et.ev_type_id = e.ev_type_id and
										e.ev_id = o.ev_id and
										o.ev_oc_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
								)
							) or
							(
								r.bet_id is null and
								r.bet_type is not null and
								r.bet_type in
								(
									select	  category
									from	  tEvClass ec
										, tEvType et
										, tEv e
										, tEvOc o
									where	ec.ev_class_id = et.ev_class_id and
										et.ev_type_id = e.ev_type_id and
										e.ev_id = o.ev_id and
										o.ev_oc_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
								)
							)
						) or
						(
							r.bet_level != "XGAME" and
							r.bet_type is null and
							r.bet_id is null
						)
					)
				)
			)
		)
	}

	


	set SHARED_SQL(fb_validate_token) {
		select
			ct.value value
		from
			tToken         t,
			tTokenAmount   ta,
			tAcct          a,
			tCustomerToken ct,
			tRedemptionVal r
		where
			ct.cust_id          = ?
			and  ct.cust_token_id    = ?
			and  t.token_id          = ct.token_id
			and  ta.token_id         = ct.token_id
			and  a.cust_id           = ct.cust_id
			and  ta.ccy_code         = a.ccy_code
			and  ct.redeemed         = 'N'
			and  ct.expiry_date      > CURRENT
			and
			(
				(
					r.redemption_id = ct.adhoc_redemp_id
				) or
				(
					r.redemption_id in (
						select
							redem.redemption_id
						from
							tPossibleBet poss,
							tRedemptionVal redem
						where
							t.token_id = poss.token_id and
							poss.redemption_id = redem.redemption_id
					)
				)
			and
			(
				r.bet_level = 'ANY' or
				(
					"XGAME" = ? and
					r.bet_level = "XGAME" and
					(
						(
							r.bet_id is not null and
						 	r.bet_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
						) or
						(
							r.bet_id is null and
							(
								(
									r.bet_type is not null and
									r.bet_type in
									(
										select	sort
										from	tXGame
										where	xgame_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
									)
								) or
								r.bet_type is null
							)
						)
					)
				) or
				(
					"SPORTS" = ? and
					(
						(
							r.bet_level = "SELECTION" and
							(
								r.bet_id is not null and
					 			r.bet_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
							)
						) or
						(
							r.bet_level = "EVENT" and
							(
								r.bet_id is not null and
								r.bet_id in
								(
									select	o.ev_id
									from    tEvOc o
									where	o.ev_oc_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
								)
							) or
							(
								r.bet_id is null and
								r.bet_type is not null and
								r.bet_type in
								(
									select	sort
									from	  tEv e
										, tEvOc o

									where	e.ev_id = o.ev_id and
										o.ev_oc_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
								)
							)
						) or
						(
							r.bet_level = "MARKET" and
							(
								r.bet_id is not null and
								r.bet_id in
								(
									select	o.ev_mkt_id
									from	tEvOc o
									where	o.ev_oc_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
								)
							) or
							(
								r.bet_id is null and
								r.bet_type is not null and
								r.bet_type in
								(
									select	sort
									from	  tEvMkt m
										, tEvOc o

									where	m.ev_mkt_id = o.ev_mkt_id and
										o.ev_oc_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
								)
							)
						) or
						(
							r.bet_level = "TYPE" and
							(
								r.bet_id is not null and
								r.bet_id in
								(
									select  t.ev_type_id
									from      tEvType t
        									, tEv e
                								, tEvoc o
        								where 	e.ev_type_id = t.ev_type_id and
										e.ev_id = o.ev_id and
										o.ev_oc_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
								)
							)
						) or
						(
							r.bet_level = "COUPON" and
							(
								r.bet_id is not null and
								r.bet_id in
								(
									select	  coupon_id
									from	  tCouponmkt cm
										, tEvMkt m
										, tEvOc o
									where 	cm.ev_mkt_id = m.ev_mkt_id and
										m.ev_mkt_id = o.ev_mkt_id and
										o.ev_oc_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
								)
							)
						) or
						(
							r.bet_level = "CLASS" and
							(
								r.bet_id is not null and
								r.bet_id in
								(
									select	  et.ev_class_id
									from	  tEvType et
										, tEv e
										, tEvOc o
									where	et.ev_type_id = e.ev_type_id and
										e.ev_id = o.ev_id and
										o.ev_oc_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
								)
							) or
							(
								r.bet_id is null and
								r.bet_type is not null and
								r.bet_type in
								(
									select	  category
									from	  tEvClass ec
										, tEvType et
										, tEv e
										, tEvOc o
									where	ec.ev_class_id = et.ev_class_id and
										et.ev_type_id = e.ev_type_id and
										e.ev_id = o.ev_id and
										o.ev_oc_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
								)
							)
						) or
						(
							r.bet_level != "XGAME" and
							r.bet_type is null and
							r.bet_id is null
						)
					)
				)
			)
		)
	}


	# given a currency code, a customer token and a game type group code, see
	# if there exists any limits for that token.
	# if there are no limits, then that token is not valid for that game.
	# Joins tToken with tCustomerToken with tGPTokGameLim on token_id.

	# the primary key for tGPTokGameLim is (token_id, gp_game_id, ccy_code)
	# therefore the number of rows returned will be 0 or 1
	# there really should only be one row in tGPGame with a given
	# ug_type_grp_code
	set SHARED_SQL(fb_gp_get_token_limits_SNG) {
		select
			l.min_stake,
			l.max_stake,
			ct.value
		from
			tToken t,
			tCustomerToken ct,
			tGPTokGameLim l,
			tGPGame g
		where
			t.token_id         = ct.token_id
		and	ct.token_id        = l.token_id
		and l.gp_game_id       = g.gp_game_id
		and ct.status          = 'A'
		and ct.expiry_date     > CURRENT
		and ((ct.redeemed  = 'N' and t.single_use = 'Y') or
			 (ct.redeemed in ('P','N') and t.single_use = 'N'))
		and g.system_arch      = 'SNG'
		and ct.cust_token_id   = ?
		and l.ccy_code         = ?
		and g.ug_type_grp_code = ?
	}



	# Mark a token as used.  Only active tokens may be spent.
	set SHARED_SQL(fb_redeem_token) {
		execute procedure pRedeemCustToken(p_cust_id=?,
											   p_cust_token_id=?,
											   p_redemption_type=?,
											   p_redemption_id=?,
											   p_redemption_amt=?,
											   p_partial_redempt=?,
											   p_do_transaction='N')
	}

	set SHARED_SQL(fb_selection_in_market) {
		select first 1 'Y'
		from
		     tevoc  o
		where
		     o.ev_mkt_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
		and
		     o.ev_oc_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
	}

	set SHARED_SQL(fb_selection_in_event) {
		select first 1 'Y'
		from
		     tevoc  o
		where
		     o.ev_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
		and
		     o.ev_oc_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
	}

	set SHARED_SQL(fb_selection_in_type) {
		select first 1 'Y' --+ ORDERED
		from
		     tevoc   o,
	         tev     e
		where
		     e.ev_type_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
		and
		     o.ev_oc_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
	    and
	         e.ev_id = o.ev_id
	}

	set SHARED_SQL(fb_selection_in_class) {
		select first 1 'Y' --+ ORDERED
		from
		     tevoc    o,
	         tev      e
		where
		     e.ev_class_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
		and
		     o.ev_oc_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
	    and
	         e.ev_id = o.ev_id
	}

	set SHARED_SQL(fb_get_voucher_data) {
		select
			voucher_key,
			type_code,
			cust_id,
			redeemed,
			trigger_id,
			valid_from,
			valid_to
		from
			tvoucher
		where
			voucher_id = ?
	}

	set SHARED_SQL(fb_redeem_voucher) {
		update	tVoucher
		set	redeemed = 'Y',
			redemption_date = CURRENT
		where	voucher_id = ?
	}

	set SHARED_SQL(fb_cust_ccy_code) {
		select
			ccy_code
		from
			tAcct
		where
			cust_id = ?
	}

	set SHARED_SQL(fb_flag_insert) {
	    insert into tCustomerFlag
	    (flag_value, cust_id, flag_name)
	    values
	    (?, ?, ?)
	}

	set SHARED_SQL(fb_flag_update) {
	    update tCustomerFlag set
	    flag_value = ?
	    where
	    cust_id   = ?  and
	    flag_name = ?
	}

	set SHARED_SQL(fb_flag_delete) {
	    delete from tCustomerFlag
	    where
	    cust_id     = ? and
	    flag_name   = ?
	}

	set SHARED_SQL(fb_flag_select) {
	    select flag_value
	    from tCustomerFlag
	    where
	    cust_id = ? and
	    flag_name = ?
	}

	set SHARED_SQL(get_max_claims) {
		select
		    o.max_claims,
		    o.unlimited_claims
		from
		    toffer o
		where
		    o.offer_id = ?
	}

	set SHARED_SQL(num_referral_claims) {
		select
		    count(claimed_offer_id) as count
		from
		    tclaimedoffer
		where
		    offer_id = ?
		and
		    cust_id = ?
	}

	set SHARED_SQL(get_ev_oc_ids_for_coupon) {
		select
			ev_oc_id
		from
			tEvOc oc,
			tCouponMkt cmkt
		where
			cmkt.coupon_id = ?
		and oc.ev_mkt_id = cmkt.ev_mkt_id
		and oc.ev_oc_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
	}

	set SHARED_SQL(fb_log_failed_check_action) {
		execute procedure pLogFailedFbAction
		(
		 p_action = ?,
		 p_cust_id = ?,
		 p_aff_id = ?,
		 p_value = ?,
		 p_evocs = ?,
		 p_sort = ?,
		 p_vch_type = ?,
		 p_vch_trigger_id = ?,
		 p_ref_id = ?,
		 p_ref_type = ?,
		 p_source = ?,
		 p_promo_code = ?
		 )
	}

	set SHARED_SQL(fb_get_failed_check_actions) {
		select
			id,
			action,
			cust_id,
			aff_id,
			value,
			evocs,
			sort,
			vch_type,
			vch_trigger_id,
			ref_id,
			ref_type,
			cr_date,
			source,
			promo_code
		from
			tFailedFbAction
	}

	set SHARED_SQL(fb_remove_failed_check_action) {
		delete from
		tFailedFbAction
		where
		id = ?
	}

	set SHARED_SQL(fb_get_failed_check_actions_count) {
		select
			count(*) as count
		from
			tFailedFbAction
	}

	set SHARED_SQL(fb_gp_get_num_plays_since_last_freebet) {
		select
			p.games  - s.last_freebet_game  as games_since,
			p.stages - s.last_freebet_stage as stages_since,
			l.gp_game_grp_id,
			s.lowest_stake,
			p.games,
			p.stages
		from
			tGPFreebetState s,
			tGPGameGrpPlays p,
			tGPGameGrpLk    l,
			tGPGame         g,
			tAcct           a
		where
			s.gp_game_grp_id = p.gp_game_grp_id
			and p.gp_game_grp_id = l.gp_game_grp_id
			and l.gp_game_id     = g.gp_game_id
			and a.cust_id        = ?
			and a.acct_id        = s.acct_id
			and s.acct_id        = p.acct_id
			and s.offer_id       = ?
			and g.cg_id          = ?
			and g.system_arch    = ?
	}

	#
	# Check if any game from a game group has been played before
	# If one row is returned and it has a num_plays of 1, that means that the current
	# game is the only game from the group that has been played.  If 2 rows, then
	# (at least) two rows exist in tCGGameLastPlay, so the group has been played at
	# least twice. If no rows are returned then something is wrong.
	set SHARED_SQL(fb_gp_has_game_group_been_played_before) {
		select
		    first 2 num_plays
		from
		    tCGGameLastPlay s,
		    tCGAcct         a,
		    tGPGame         g,
		    tGPGameGrpLk    l,
		    tTrigger        t
		where
		    s.cg_acct_id     = a.cg_acct_id     and
		    a.cust_id        = ?                and
		    g.cg_id          = s.cg_id          and
		    g.system_arch    LIKE '%FOG'        and
		    l.gp_game_id     = g.gp_game_id     and
		    l.gp_game_grp_id = t.gp_game_grp_id and
		    t.trigger_id     = ?
	}

	# Check if any rows exist in tUGDrawAccount for that customer, for that draw group.
	# If there are no rows, then the customer has not played this group of game before.
	set SHARED_TCL(fb_gp_sng_has_game_group_been_played_before) {
		select
			da.first_draw_id
		from
			tTrigger               t,
			tGPGame               g,
			tUGDrawAcct           da,
			tAcct                 a
		where
			a.cust_id             = ?
		and a.acct_id             = da.acct_id
		and t.trigger_id          = ?
		and t.gp_game_id          = g.gp_game_id
		and g.system_arch         = 'SNG'
		and g.ug_type_grp_code    = da.ug_type_grp_code;
	}


	# when an offer is obtained, update the games and stages in
	# tCGFreebetState
	set SHARED_SQL(fb_gp_reset_num_plays_for_freebet) {
		execute procedure pUpdGPFBStReset
		(
		 p_cust_id=?,
		 p_gp_game_grp_id=?,
		 p_offer_id=?
		 )
	}

	## TODO: review this sql
	set SHARED_SQL(fb_gp_get_cust_stake_amt_SNG) {
		select
			nvl(sum(ds.stake_per_draw * num_draws),0)
									as amount_staked
		from
			tTrigger             tt,
			tGPGame              gg,
			tUGGameType          gt,
			tUGDrawDef           dd,
			tUGDrawSub           ds,
			tOffer               ofr,
			tGPGameGrpLk         ggl,
			tAcct                a
		where
		    tt.trigger_id        = ?
		and ofr.offer_id          = tt.offer_id

		and ds.cr_date           >= ofr.start_date
		and ds.cr_date           <= ofr.end_date

		-- draw subs must be on games specified by tTrigger
		and ggl.gp_game_grp_id   = tt.gp_game_grp_id
		and gg.gp_game_id        = ggl.gp_game_id
		and gt.ug_type_grp_code  = gg.ug_type_grp_code
		and dd.ug_type_code      = gt.ug_type_code
		and ds.ug_draw_def_id    = dd.ug_draw_def_id

		and a.cust_id            = ?
		and a.ccy_code           = ?
		and ds.acct_id           = a.acct_id;
	}

	set SHARED_SQL(fb_gp_get_cust_stake_amt_FOG) {
		select
			nvl(sum(gs.stakes),0) as amount_staked
		from
			tTrigger              tr,
			tOffer                ofr,
			tCGGSFinished         sf,
			tCGGameSummary        gs,
			tGPGame               gm,
			tGPGameGrpLk          ggl,
			tCGAcct               ca,
			tAcct                 a

		where
			tr.trigger_id         = ?
		and ofr.offer_id          = tr.offer_id

		-- find all rows within offer period
		and gs.started            >= ofr.start_date
		and sf.finished           <= ofr.end_date

		-- games must be specified in the trigger
		and ggl.gp_game_grp_id    = tr.gp_game_grp_id
		and gm.gp_game_id         = ggl.gp_game_id
		and gs.cg_id              = gm.cg_id
		and sf.cg_game_id         = gs.cg_game_id

		-- match currencies and account
		and a.cust_id             = ?
		and a.ccy_code            = ?
		and ca.cg_acct_id         = gs.cg_acct_id
		and a.acct_id             = ca.acct_id
	}

	# a query to find out how many times a trigger has been 'called' (turned
	# into a customer token) for a customer. It should only be 0 or 1 if things
	# are done properly
	set SHARED_SQL(fb_gp_count_times_trigger_called_for_cust) {
		select
			count(cust_id)       as value
		from
			tCalledTrigger
		where
			trigger_id           = ?
		and cust_id              = ?;
	}

	# Get a global list of trigger information
	set SHARED_SQL(fb_global_triggers) {
		select
			o.name,
			o.start_date,
			o.end_date,
			o.channels,
			t.trigger_id,
			t.type_code,
			t.text,
			t.aff_id,
			ta.amount,
			ta.ccy_code,
			o.lang,
			o.country_code
		from
			tTrigger       t,
			tTriggerAmount ta,
			tOffer         o
		where
			t.trigger_id = ta.trigger_id and
			t.offer_id = o.offer_id and
			t.type_code  in (?,?,?,?,?) and
			o.start_date              <= extend(current, year to hour) + interval (1) hour to hour and
			nvl(o.end_date,current)   >= extend(current, year to hour) and
			ta.ccy_code  =  ?
	}

	set SHARED_SQL(cache,fb_global_triggers) [OT_CfgGet GLOBAL_FREEBETS_TRIGGERS_CACHE_TIME 300]

	set SHARED_SQL(check_for_first_action) {
		select
			s.first_date
		from
			tAcct a,
			tCustStats s,
			tCustStatsAction ac
		where
			a.cust_id      = ?            and
			a.acct_id      = s.acct_id    and
			s.action_id    = ac.action_id and
			s.source       like ?         and
			s.first_ref_id < ?            and
			ac.action_name = ?
	}

	# find offer triggers
	set SHARED_SQL(fb_find_offer_triggers_for_offer) {
		select
			t.trigger_id,
			t.offer_id
		from
			tTrigger t,
			tOffer o
		where
			t.fulfilled_offer = ?
		and     t.type_code = "OFFER"
		and     t.offer_id = o.offer_id
		and     o.start_date <= ?
		and     (o.end_date is null or o.end_date > ?)
		and     (o.unlimited_claims = 'Y'
			or o.max_claims > (
				select
					count(ct.called_trigger_id)
				from
					tCalledTrigger ct
				where
					ct.trigger_id = t.trigger_id
				and     ct.cust_id = ?
			))
	}

	# check the existence of a completion message in an offer
	set SHARED_SQL(fb_check_offer_completion_msg) {
		select
			o.completion_msg_id
		from
			tOffer o
		where
			o.offer_id = ?
	}

	# insert the completion message in the customer's message queue
	set SHARED_SQL(fb_insert_offer_completion_msg_for_cust) {
		insert into tCMMsgCust (
			msg_id,
			cust_id
		) values (
			?,
			?
		)
	}
}

#
# Initialise FreeBets
#

proc OB_freebets::init_freebets {} {

	variable log_name

	set log_name "default"

	OT_LogWrite 1 "log name is set to $log_name"

	if {[OT_CfgGet FREEBET_LOG_FILE ""] != ""} {
		set file     [OT_CfgGet LOG_DIR ""]
		lappend file [OT_CfgGet FREEBET_LOG_FILE]

		set file [join $file "/"]
		if {[catch {set log_name [OT_LogOpen -mode append -level 100 $file]} msg]} {
			OT_LogWrite 1 "failed to open log file: $msg"
		}
	}

	prep_freebets_qrys

	if {[OT_CfgGet ENABLE_FOG 0]} {
		package require games_gpm_triggers
		ob::games::triggers::init
	}

	if {[OT_CfgGet IS_FREEBETS_SERVER 0]} {
		package require tdom
	}

}

proc OB_freebets::db_init {} {
	OB_db::db_init
}

#
# Display row,column from result set.  Nicked from the admin screens
#

proc sb_res_data {res row col} {
	tpBufWrite [db_get_col $res [tpGetVar $row] $col]
}

#
# FreeBets logging function
# ----------------------------------------------------------------------

proc OB_freebets::log {level msg} {
	OT_LogWrite $level "FREEBET: $msg"
}

#
# Procedure to get a customer's currency code
#
proc OB_freebets::get_cust_ccy_code {cust_id} {
	#we really don't want to be contacting the db everytime
	#just to get the ccy_code
	global _cust_ccy_code

	if {[info exists _cust_ccy_code] && $cust_id == [lindex $_cust_ccy_code 0]} {
		return [lindex $_cust_ccy_code 1]
	}

	if [catch {set cust_rs [tb_db::tb_exec_qry fb_cust_ccy_code $cust_id]} msg] {
		log 1 "Failed to get customer ccy_code for $cust_id: $msg"
		return 0
	} else {
		set nrows [db_get_nrows $cust_rs]

		if {$nrows == 1} {
			set ccy_code [db_get_col $cust_rs 0 ccy_code]
			set _cust_ccy_code [list $cust_id $ccy_code]

			log 3 "Customer $cust_id ccy_code $ccy_code"
			tb_db::tb_close $cust_rs
			return $ccy_code
		} else {
			log 1 "Failed to get exactly one ccy_code for $cust_id"
			tb_db::tb_close $cust_rs
			return 0
		}
	}

}


#
# Given an action, check whether it fulfills any triggers for user
#
# the evocs list will be provided for BET action and BUYMGETN
#
# ref_id     is the id of the sports bet, xgames bet, cg_id or ug_draw_def_id
# ref_type   will be SPORTS, XGAME, FOG or SNG
# promo_code is a string that the customer types in that is checked against
#            the promo code stored in a trigger

proc OB_freebets::check_action {
	  action
	  user_id
	{ aff_id          0 }
	{ value           0 }
	{ evocs          -1 }
	{ sort           "" }
	{ vch_type       "" }
	{ vch_trigger_id "" }
	{ ref_id         "" }
	{ ref_type       "" }
	{ promo_code     "" }
	{ in_db_trans     0 }
	{ source         "" }
} {

	global CHANNEL

	if {$source != ""} {
		# override with arg
		log 1 "Established source from arg"
	} elseif {![info exists CHANNEL]} {
		# cfg
		log 1 "Established source from cfg"
		set source [OT_CfgGet CHANNEL I]
	} else {
		# global
		log 1 "Established source from global"
		set source $CHANNEL
	}

	if {[OT_CfgGetTrue USE_FREEBETS_SERVER]} {

		check_action_http_req $action \
							  $user_id \
							  $aff_id \
							  $value\
							  $evocs \
							  $sort \
							  $vch_type \
							  $vch_trigger_id \
							  $ref_id \
							  $ref_type\
							  $source \
							  $promo_code

		return 1

	} else {

		#
		# Return an error if not logged in
		#
		if {$user_id == "-1"} {
			log 1 "Guest user not allowed"
			return 0
		}

		set date [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]

		return [check_action_local $action \
								   $user_id \
								   $aff_id \
								   $value\
								   $evocs \
								   $sort \
								   $vch_type \
								   $vch_trigger_id \
								   $ref_id\
								   $ref_type \
								   $date \
								   $source \
								   $promo_code\
								   $in_db_trans]

	}

}



proc OB_freebets::_rollback_trans {msg} {
	log 2 "Rolling back transaction: $msg"

	# TODO (will this roll back the trans?)
	tb_db::tb_rollback_tran
}

# if the in_db_trans is set to 1, we need to rollback *on any error*!
proc OB_freebets::check_action_local {
	action
	user_id
	aff_id
	value
	evocs
	sort
	vch_type
	vch_trigger_id
	ref_id
	ref_type
	action_date
	source
	promo_code
	{in_db_trans 0}
} {
	global LOGIN_DETAILS
	global REDEEM_VOUCHER
	global FB_OFFERS_ARR
	global CLAIMED_OFFERS

	variable TRIGGER_FULFILLED
	set TRIGGER_FULFILLED 0

	log 1 "CHECK_ACTION_LOCAL:action:$action"
	log 1 "                   user_id:$user_id"
	log 1 "                   aff_id:$aff_id"
	log 1 "                   value:$value"
	log 1 "                   evocs:$evocs"
	log 1 "                   sort:$sort"
	log 1 "                   vch_type:$vch_type"
	log 1 "                   vch_trigger_id:$vch_trigger_id"
	log 1 "                   ref_id:$ref_id"
	log 1 "                   ref_type:$ref_type"
	log 1 "                   action_date:$action_date"
	log 1 "                   source:$source"
	log 1 "                   promo_code:$promo_code"
	log 1 "                   action_date:$action_date"
	log 1 "                   in_db_trans:$in_db_trans"


	## Return an error if not logged in

	if {$user_id == "-1"} {
		log 1 "Guest user not allowed"
		if {$in_db_trans} {
			_rollback_trans "Guest user not allowed"
		}
		return 0
	}

	#
	 # Optimisation code in here. Try to compare various details of the trigger
	 # against a cached list of triggers to see if it's "likely" that the trigger
	 # will fire. Anything we can do to avoid getting unnecessarily into freebets
	 # code the better.

	 if {[OT_CfgGet USE_GLOBAL_TRIGGER_OPTIMISATION 1]} {
			 #
			 # Quick sanity check we can actually do what we're trying to do in this
			 # optimisation check. It needs access to various bits in LOGIN_DETAILS
			 # which may not exist.

			 if {[info exists LOGIN_DETAILS(CCY_CODE)] && [info exists LOGIN_DETAILS(LANG)] && [info exists LOGIN_DETAILS(CNTRY_CODE)]} {
					 #
					 # check the info passed in against the global triggers

					 log 10 "check_action_local:: USE_GLOBAL_TRIGGER_OPTIMISATION set to on - checking global triggers"

					 set max_items 5
					 set action_list $action

					 log 10 "check_action_local:: Numbers of actions: [llength $action_list]"

					 while {[expr [llength $action_list] % $max_items] != 0} {
							 lappend action_list -1
					 }

					 while {[llength $action_list] > 0} {
							 set subset [lrange $action_list 0 [expr $max_items - 1]]
							 lappend subset $LOGIN_DETAILS(CCY_CODE)

							 log 10 "check_action_local:: tb_db::tb_exec_qry fb_global_triggers $subset"

							if {[catch {set global_triggers_rs [eval "tb_db::tb_exec_qry fb_global_triggers $subset"]} msg]} {
											 log 1 "Failed to get global triggers for $action_date, $action_date: $msg"
											 return 0
							 }

							 set nrows [db_get_nrows $global_triggers_rs]

							 log 10 "check_action_local:: Number of global triggers: [db_get_nrows $global_triggers_rs]"

							 set any_matches 0

							 # Check action data against all triggers
							 for {set i 0} {$i < $nrows} {incr i} {

									 set trigger_sources      [db_get_col $global_triggers_rs $i channels]
									 set trigger_aff_id       [db_get_col $global_triggers_rs $i aff_id]
									 set trigger_amount       [db_get_col $global_triggers_rs $i amount]
									 set trigger_lang         [db_get_col $global_triggers_rs $i lang]
									 set trigger_country_code [db_get_col $global_triggers_rs $i country_code]

									 # Note we don't check everything, some things (like aff_grp_id)
									 # require extra queries.
									 if {($trigger_sources      == "" || [string first $source $trigger_sources] != -1) && \
											 ($trigger_aff_id       == "" || $trigger_aff_id == $aff_id) && \
											 ($trigger_amount       == "" || $trigger_amount <= $value) && \
											 ($trigger_lang         == "" || [lsearch [split $trigger_lang ","] $LOGIN_DETAILS(LANG)] >= 0) && \
											 ($trigger_country_code == "" || $trigger_country_code == $LOGIN_DETAILS(CNTRY_CODE))} {
													 set any_matches 1
													 break
									 }
							 }

							 #
							 # If we've found a matching trigger, we need to go into the main freebets
							 # checks so no point carrying on with this check.

							 if {$any_matches == 1} {
									 break
							 }

							 set action_list [lreplace $action_list 0 [expr $max_items - 1]]
					 }

					 log 10 "check_action_local:: any matches from global trigger check: $any_matches"

					 # If any of the triggers are a match, we need to check further.
					 if {$any_matches != 1} {
							 # No triggers were a match. Don't need to go into further freebets cide
							 # as it won't result in anything being fired.
							 return 1
					 }
			 }
	 }

	#can we use the cached data?
	set use_cache 0
	if {[info exists FB_OFFERS_ARR] && [info exists FB_OFFERS_ARR($user_id,req_id)] && ([reqGetId] == $FB_OFFERS_ARR($user_id,req_id))} {
		#we're at least  on the same request
		#Are we examining the same trigger types
		#doesn't matter if there's more in the existing list.
		#These will be ignored later on.

		set use_cache 1
		foreach act $action {
			if {[lsearch $FB_OFFERS_ARR($user_id,types) $act] == -1} {
				set use_cache 0
				break
			}
		}
	}

	if {!$use_cache} {
		set ret [OB_freebets::get_check_action_data $action $user_id $source $action_date]
		if {$ret == 0} {
			if {$in_db_trans} {
				_rollback_trans "get_check_action_data failed"
			}
			return 0
		}
	}

	set CLAIMED_OFFERS [list]

	foreach offer_id $FB_OFFERS_ARR($user_id,offers) {

		get_trigger_list $user_id $offer_id

		foreach trigger_id $FB_OFFERS_ARR($user_id,$offer_id,trigger_ids) {

			if {[lsearch $action $FB_OFFERS_ARR($user_id,$offer_id,$trigger_id,type_code)] == -1} {
				continue
			}

			set rank  $FB_OFFERS_ARR($user_id,$offer_id,$trigger_id,rank)
			set qual  $FB_OFFERS_ARR($user_id,$offer_id,$trigger_id,qualification)
			set code  $FB_OFFERS_ARR($user_id,$offer_id,$trigger_id,type_code)
			set char  $FB_OFFERS_ARR($user_id,$offer_id,$trigger_id,char)
			set float $FB_OFFERS_ARR($user_id,$offer_id,$trigger_id,float)

			set earlier_triggers 0

			log 15 "checking Offer ID: $offer_id"

			# If this is not a qualification trigger, check if
			# there are any qualification triggers or triggers with
			# an earlier order to be fulfilled first.
			if {$qual != "Y"} {
				if [catch {set trig_rs [tb_db::tb_exec_qry fb_earlier_trigs \
											$offer_id \
											$trigger_id \
											$user_id \
											$rank \
										   ]} msg] {
					log 1 "Failed to get earlier triggers for $user_id: $msg"

					if {$in_db_trans} {
						_rollback_trans "Failed to get earlier triggers \
							for $user_id: $msg"
					}

					return 0
				}

				if {[db_get_nrows $trig_rs] != 1} {
					set err_msg "pEarlierTriggers returned more than one row!  This should not happen"
					log 1 $err_msg
					catch {tb_db::tb_close $trig_rs}
					if {$in_db_trans} {
						_rollback_trans $err_msg
					}
					return 0
				}

				set earlier_triggers [db_get_coln $trig_rs 0]
				catch {tb_db::tb_close $trig_rs}
			}

			if { $earlier_triggers != 0 } {
				log 10 "Earlier triggers exist than $code.  Number of earlier triggers: $earlier_triggers"
			} else {
				# Check if this action fulfills the given trigger
				log 1 "CHECK_TRIGGER:code:$code"
				log 1 "              trigger_id:$trigger_id"
				log 1 "              aff_id:$aff_id"
				log 1 "              value:$value"
				log 1 "              evocs:$evocs"
				log 1 "              sort:$sort"
				log 1 "              vch_type:$vch_type"
				log 1 "              vch_trigger_id:$vch_trigger_id"
				log 1 "              source:$source"
				log 1 "              ref_id:$ref_id"
				log 1 "              ref_type:$ref_type"
				log 1 "              promo_code:$promo_code"
				log 1 "              in_db_trans:$in_db_trans"

				set check_trigger_result [check_trigger $user_id $code $trigger_id $aff_id $value $evocs $sort $vch_type $vch_trigger_id $source $ref_id $ref_type $promo_code $in_db_trans]

				if {[lindex $check_trigger_result 0]} {
					# if the trigger was a buymgetn, then a value for the lowest game played
					# will be returned as well, use this instead of the passed in value
					if {[llength $check_trigger_result] == 2} {
						set value [lindex $check_trigger_result 1]
						log 1 "Using lowest game value of $value"
					}
					# Fulfill trigger, and claim offer
					if {! [fulfill_trigger $trigger_id $offer_id $user_id $ref_id $ref_type $rank $action_date $value $source $in_db_trans]} {
						set err_msg "Action did not fulfill trigger $trigger_id"
						log 1 $err_msg

						if {$in_db_trans} {
							_rollback_trans $err_msg
						}

						return 0
					}
					set TRIGGER_FULFILLED 1
					log 15 "Trigger ID: $trigger_id fulfilled"
					if {$code == "VOUCHER"} {
						log 15 "Setting REDEEM_VOUCHER to 1 so that voucher will be redeemed."
						set REDEEM_VOUCHER 1
					}
				}
			}
		}
	}


	if {[llength $CLAIMED_OFFERS]} {
		# Populate FB_OFFERS_ARRAY with OFFERS - flush cache
		log 10 "Offers have been claimed populated offers array with OFFERS"
		get_check_action_data "OFFER" $user_id $source $action_date 1
	}

	for {set j 0} {$j < [llength $CLAIMED_OFFERS]} {incr j} {
		set offer_id [lindex $CLAIMED_OFFERS $j]
		log 10 "Call claimed offer trigger for offer $offer_id"

		if [catch {set otrs [tb_db::tb_exec_qry fb_find_offer_triggers_for_offer \
					$offer_id \
					$action_date \
					$action_date \
					$user_id]} msg] {
			log 1 "Could not get offer triggers: $msg"
			return 0
		}

		set otnrows [db_get_nrows $otrs]

		for {set i 0} {$i < $otnrows} {incr i} {
			set o_trigger_id [db_get_col $otrs $i trigger_id]
			set o_offer_id   [db_get_col $otrs $i offer_id]

			# Fulfill offer trigger
			if {! [fulfill_trigger $o_trigger_id $o_offer_id $user_id $ref_id \
					$ref_type \
					"" "" "" \
					$source \
					$in_db_trans]} {
				set err_msg "Action did not fulfill trigger $o_trigger_id"
				log 1 $err_msg

				if {$in_db_trans} {
					_rollback_trans $err_msg
				}
				tb_db::tb_close $otrs
				return 0
			}
			log 15 "Offer Trigger ID: $o_trigger_id fulfilled"
		}
		catch {tb_db::tb_close $otrs}
	}
	return 1
}




#
# Gets data together in preparation for checking the action against the trigger.
#
# returns: 0 on error, 1 on OK
#
# action         - code for what the user has done to check trigger
# user_id        - customer id
# source         - where action came from
# action_date    - date action took place
# flush_cache    - whether to unset FB_OFFERS_ARR array

proc OB_freebets::get_check_action_data {action user_id source action_date {flush_cache 1}} {

	global FB_OFFERS_ARR

	#hack together the offers so that we can do them all in one query
	#-- we can examine up to 6 types in one qry
	#can't think we'd want to do more than that
	set act_lgth [llength $action]

	if {$act_lgth > 6 || $act_lgth == 0} {
		log 1 "Can only handle 1-6 actions at a time"
		return 0
	}

	for {set i 1} {$i <= 6} {incr i} {
		if {$i <=  $act_lgth} {
			set act${i} [lindex $action [expr {$i-1}]]
		} else {
			#pad out with the first action
			set act${i} [lindex $action 0]
		}
	}

	log 10 "Checking actions $action"

	# Grab offers for which this action may fulfil a trigger
	if {[catch {set off_rs [tb_db::tb_exec_qry fb_offers $action_date \
	                                                     $action_date \
	                                                     $action_date \
	                                                     $user_id \
	                                                     $user_id \
	                                                     $act1 \
	                                                     $act2 \
	                                                     $act3 \
	                                                     $act4 \
	                                                     $act5 \
	                                                     $act6 \
	                                                     "%$source%" \
	                                                     $user_id ]} msg]} {
		log 1 "Failed to get offers for $user_id: $msg"
		return 0
	}

	set nrows_offs [db_get_nrows $off_rs]
	log 15 "Number of offer/triggers to check = $nrows_offs"

	if {$flush_cache == 1} {
		array unset FB_OFFERS_ARR
		set FB_OFFERS_ARR($user_id,offers) [list]
	}

	set FB_OFFERS_ARR($user_id,types)  $action
	set FB_OFFERS_ARR($user_id,req_id) [reqGetId]

	set curr_offer_id -1
	set curr_trig_id -1

	for {set i 0} {$i < $nrows_offs} {incr i} {
		foreach f {
			offer_id
			max_claims
			unlimited_claims
			type_code
			trigger_id
			called_trigger_id
			rank
			char
			float
			qualification
			promo_code
		} {
			set $f [db_get_col $off_rs $i $f]
		}

		if {$offer_id != $curr_offer_id} {
			set curr_offer_id $offer_id
			lappend FB_OFFERS_ARR($user_id,offers) $offer_id

			set FB_OFFERS_ARR($user_id,$offer_id,trigger_ids) [list]
			set FB_OFFERS_ARR($user_id,$offer_id,max_claims) $max_claims
			set FB_OFFERS_ARR($user_id,$offer_id,unlimited_claims) $unlimited_claims
			set curr_trig_id -1
			set bad_trigger -1
		}

		if {$trigger_id == $bad_trigger} {
			#trigger has already been discounted as it has been called > num times
			continue
		}

		if {$curr_trig_id !=  $trigger_id} {
			#check to see if we're over the max claims for the previous trigger
			set curr_trig_id $trigger_id
			lappend FB_OFFERS_ARR($user_id,$offer_id,trigger_ids) $trigger_id

			set FB_OFFERS_ARR($user_id,$offer_id,$trigger_id,num_triggered) 0

			set FB_OFFERS_ARR($user_id,$offer_id,$trigger_id,type_code) $type_code
			set FB_OFFERS_ARR($user_id,$offer_id,$trigger_id,rank) $rank
			set FB_OFFERS_ARR($user_id,$offer_id,$trigger_id,char) $char
			set FB_OFFERS_ARR($user_id,$offer_id,$trigger_id,float) $float
			set FB_OFFERS_ARR($user_id,$offer_id,$trigger_id,qualification) $qualification
			set FB_OFFERS_ARR($user_id,$offer_id,$trigger_id,promo_code) $promo_code
		}

		if {$called_trigger_id != ""} {
			incr FB_OFFERS_ARR($user_id,$offer_id,$trigger_id,num_triggered)
			# If the offer can only be obtained a limited number of times,
			# check how many so far
			if {$FB_OFFERS_ARR($user_id,$offer_id,unlimited_claims) == "N" &&
			    ($FB_OFFERS_ARR($user_id,$offer_id,$trigger_id,num_triggered)
				 >= $FB_OFFERS_ARR($user_id,$offer_id,max_claims))} {
				# Remove this trigger from the list - we know it's the one on
				# the end
				set FB_OFFERS_ARR($user_id,$offer_id,trigger_ids) [lrange $FB_OFFERS_ARR($user_id,$offer_id,trigger_ids) 0 end-1]
				set bad_trigger $trigger_id
			}
		}
	}

	foreach offer $FB_OFFERS_ARR($user_id,offers) {
		# for each offer get the valid list of
		# triggers to check in check_trigger
		get_trigger_list  $user_id $offer
	}

	catch {tb_db::tb_close $off_rs}
	return 1
}


#
# Check that the action fulfills the given trigger.  Returns a list [success value]
# If the action matches the trigger success = 1, if the trigger is of BUYMGETN then
# value will be looked up in the database
#
# user_id        - customer id
# action         - code for what the user has done to check trigger
# trigger_id     - tTrigger.trigger_id
# aff_id         - affiliate id of action, checked against affiliate or
#                  group as appropriate
# value          - value of first bet/xgame bet/generic bet/deposit
# evocs          - event outcome ids
# sort           - outcomes that the user is betting on (if appropriate)
# vch_type       - tTrigger.voucher_type
# vch_trigger_id - tVoucher.trigger_id
# source         - where action came from
# ref_type       - SPORTS, XGAME, FOG or SNG
# in_db_trans    - if true, then rollback on any error

proc OB_freebets::check_trigger {
	user_id
	action
	trigger_id
	aff_id
	value
	evocs
	sort
	vch_type
	vch_trigger_id
	source
	ref_id
	ref_type
	promo_code
	in_db_trans
} {

	log 10 "Checking $action against trigger $trigger_id\
				with params $user_id\
							$value\
							$evocs\
							$sort\
							$vch_type\
							$vch_trigger_id\
							$source\
							$ref_id\
							$ref_type\
							$promo_code"

	# Grab details of trigger

	set cust_ccy_code [get_cust_ccy_code $user_id]
	if [catch {set rs [tb_db::tb_exec_qry fb_trigger_details $trigger_id $cust_ccy_code]} msg] {
		set err_msg "Failed to get trigger details for $trigger_id: $msg"
		log 1 $err_msg
		if {$in_db_trans} {
			_rollback_trans $err_msg
		}
		return [list 0]
	}

	if {[db_get_nrows $rs] != 1} {
		set err_msg "fb_trigger_details returned != 1 row for $trigger_id"
		log 1 $err_msg
		if {$in_db_trans} {
			_rollback_trans $err_msg
		}
		return [list 0]
	}

	# float represents the actual amount that the trigger demands, in a
	# particular currency (cust_ccy_code)

	# Grab DB values
	set float 				[db_get_col $rs 0 float]
	set char 				[db_get_col $rs 0 char]
	set aff_level 			[db_get_col $rs 0 aff_level]
	set trg_aff_id 			[db_get_col $rs 0 aff_id]
	set trg_aff_grp_id		[db_get_col $rs 0 aff_grp_id]
	set trg_voucher_type	[db_get_col $rs 0 voucher_type]
	set channel_strict      [db_get_col $rs 0 channel_strict]
	set buy_m               [db_get_col $rs 0 buy_m]
	set trg_promo_code		[db_get_col $rs 0 promo_code]
	set offer_id            [db_get_col $rs 0 offer_id]

	# check trigger affiliate details against user's affiliate
	switch -exact -- $aff_level {

		Single {
			# Trigger is associated with a particular affiliate
			if {$aff_id != $trg_aff_id} {
				log 15 "User aff_id $aff_id doesn't match trigger with Single aff_id $trg_aff_id"
				return [list 0]
			}
			log 15 "User aff_id $aff_id matched trigger with Single aff_id $trg_aff_id"
		}

		Group {
			# Trigger is associated with an affiliate group

			# get the affiliate group id for the user's affiliate
			if [catch {set rs1 [tb_db::tb_exec_qry fb_get_aff_grp $aff_id]} msg] {
				log 1 "Failed to get affiliate group id for $aff_id: $msg"
				return [list 0]
			}
			if {[db_get_nrows $rs1] != 1} {
				log 1 "get_aff_id returned <> 1 row for $aff_id"
				tb_db::tb_close $rs1
				return [list 0]
			} else {
				set aff_grp_id [db_get_col $rs1 0 aff_grp_id]
				tb_db::tb_close $rs1

				# if the user's affiliate group doesn't match the affiliate group of the trigger return
				if {$aff_grp_id != $trg_aff_grp_id} {
					log 15 "User aff_id $aff_id with aff_grp_id $aff_grp_id doesn't match trigger with Group aff_grp_id $trg_aff_grp_id"
					return [list 0]
				}
			}
			log 15 "User aff_id $aff_id with aff_grp_id $aff_grp_id matched trigger with Group aff_grp_id $trg_aff_grp_id"
		}

		All {
			# check users aff_id is valid

			# if aff_id = 0 then return
			if {$aff_id == 0} {
				log 15 "User aff_id $aff_id doesn't match trigger with All affiliate option."
				return [list 0]
			}

			# try to get the aff_id from taffiliate for the user's aff_id
			if [catch {set rs1 [tb_db::tb_exec_qry fb_get_valid_aff $aff_id]} msg] {
				log 1 "Failed to get affiliate group id for $aff_id: $msg"
				return [list 0]
			}
			if {[db_get_nrows $rs1] == 0} {
				# no entry for that aff_id exists so aff_id is invalid
				log 3 "User aff_id $aff_id doesn't match trigger with All affiliate option."
				return [list 0]
			}
			log 15 "User aff_id $aff_id matched trigger with All affiliate option."
		}

		None {
			# aff_id should be 0 else return
			if {$aff_id != 0 && $aff_id != ""} {
				log 15 "User aff_id $aff_id doesn't match trigger with None affiliate option."
				return [list 0]
			}
			log 15 "User aff_id $aff_id matched trigger with None affiliate option."
		}

		default {
			# trigger does not care about affiliate at all
			log 15 "Trigger doesn't have any affiliate preference,"
		}

	}

	if {$action == "REG"} {
		# Registration
		log 3 "$action matched"
		return [list 1]
	} elseif {$action == "VOUCHER"} {
		if {$vch_type != $trg_voucher_type || $vch_trigger_id != $trigger_id} {
			log 10 "No match for $action and $vch_type and vch_trigger_id $vch_trigger_id and triggerid $trigger_id"
			return [list 0]
		} else {
			log 3 "$action matched $vch_type and $vch_trigger_id"
			return [list 1]
		}
	} elseif {$action == "REFERRAL"} {
		return [list 1]
	} elseif {$action == "REFEREE"} {
		return [list 1]
	} elseif {$action == "DEP" || $action == "DEP1" } {
		# Deposit
		if { $float != "" && $value < $float } {
			log 10 "No match for $action"
			return [list 0]
		} else {
			# Special channel strict handling for DEP1
			log 20 {check_trigger:: channel: $source - channel_strict: $channel_strict - action: $action}

			if {$action == "DEP1"} {
				if {[OT_CfgGet USE_CUST_STATS 0]} {
					if {[check_for_first_action $user_id "DEPOSIT" $channel_strict $source $ref_id] == 0} {
						return [list 0]
					}
				} else {
					if {[check_channels $user_id "chan_dep_thru" $channel_strict $source] == 0} {
						return [list 0]
					}
				}
			}

			log 3 "$action matched $value"
			return [list 1]
		}
	} elseif {$action == "BET1"} {
		# First Bet
		if { $float != "" && $value < "$float"} {
			log 10 "No match for $action"
			return [list 0]
		} else {
			# Special channel strict handling for FBET
			log 20 {check_trigger:: channel: $source - channel_strict: $channel_strict - action: $action}

			if {[OT_CfgGet USE_CUST_STATS 0]} {
				if {[check_for_first_action $user_id "BET" $channel_strict $source $ref_id] == 0} {
					return [list 0]
				}
			} else {
				if {[check_channels $user_id "chan_bet_thru" $channel_strict $source] == 0} {
					return [list 0]
				}
			}

			log 3 "$action matched '$float' & '$char'"
			log 3 "value > float: $float"
			return [list 1]
		}
	} elseif {$action == "XGAMEBET" || $action == "XGAMEBET1"} {
		# External game bet
		if { ($char != "" && $sort != $char) || ($float != "" && $value < $float)} {
			log 10 "$char does not match $sort and/or $float does not match $value for $action"
			return [list 0]
		} else {
			# Special channel strict handling for XGAMEBET1
			log 20 {check_trigger:: channel: $source - channel_strict: $channel_strict - action: $action}

			if {$action == "XGAMEBET1"} {
				if {[OT_CfgGet USE_CUST_STATS 0]} {
					if {[check_for_first_action $user_id "XGAME_BET" $channel_strict $source $ref_id] == 0} {
						return [list 0]
					}
				} else {
					if {[check_channels $user_id "chan_bet_thru" $channel_strict $source] == 0} {
						return [list 0]
					}
				}
			}

			log 3 "$action matched '$float' & '$char'"
			return [list 1]
		}
	} elseif {$action == "POOLBET"} {
		#Tote Pool Bet
		log 20 {check_trigger:: channel: $source - channel_strict: $channel_strict - float: $float - value: $value}

		if { ($char != "" && $sort != $char) || ($float != "" && $value < $float)} {
			log 10 "$char does not match $sort and/or $float is smaller than $value for $action"
			return [list 0]
		} else {
			log 3 "$action matched '$float' & '$char'"
			return [list 1]
		}
	} elseif {$action == "SPORTSBET" || $action == "SPORTSBET1"} {
		# Sportsbook bet
		log 20 {check_trigger:: channel: $source - channel_strict: $channel_strict - float: $float - value: $value}

		if { $float != "" && $value < "$float"} {
			log 10 "No match for $action"
			return [list 0]
		} else {
			# Special channel strict handling for SPORTSBET1
			log 20 {check_trigger:: channel: $source - channel_strict: $channel_strict - action: $action}

			if {$action == "SPORTSBET1"} {
				if {[OT_CfgGet USE_CUST_STATS 0]} {
					if {[check_for_first_action $user_id "BET"  $channel_strict $source $ref_id] == 0} {
						return [list 0]
					}
				} else {
					if {[check_channels $user_id "chan_bet_thru" $channel_strict $source] == 0} {
						return [list 0]
					}
				}
			}

			log 3 "$action matched '$float' & '$char'"
			log 3 "value > float: $float"
			return [list 1]
		}
	} elseif {$action == "BET"} {
		# Generic bet

		if {$value >= $float} {
			log 10 "bet stake greater than trigger float amount"
			log 10 "stake: $value >= trig: $float"

			if {[catch {
				set trigger_levels [_get_trigger_levels $trigger_id]
			} msg]} {
				log 1 "Failed to get trigger levels for trigger $trigger_id: $msg"
				return [list 0]
			}

			# if there are none, then we match all levels
			if {[llength $trigger_levels] == 0} {
				set trigger_levels [list "ANY" $trigger_id]
			}

			#
			# this changes the data, so that we get lists of the different
			# triggers. it makes the follow part more efficient
			# (particulary calls to check_ev_oc_in_range)
			#
			# i.e
			#    % array get TRIGGER_LEVELS
			#      CLASS 2 TYPE {345 43} SELECTION 245
			#
			array unset TRIGGER_LEVELS
			foreach {level id} $trigger_levels {
				lappend TRIGGER_LEVELS($level) $id
			}


			#
			# attempt to match the levels to the various triggers
			# we only need to match one level, we don't bother ordering
			# here, though we could do selections first and then go up the
			# heirachy
			#
			# note that someone may have defined some game trigger levels
			# FOG, SNG etc. this procedure will skip over them
			#
			foreach {level ids} [array get TRIGGER_LEVELS] {
				log 10 "Checking trigger level $level, $ids"
				if {[check_ev_oc_in_range $level $ids $evocs]} {
					return [list 1]
				}
			}
			return [list 0]
		} else {
			return [list 0]
		}
	} elseif {$action == "INTRO"} {
		if {$sort != $char} {
			return [list 0]
		}
		return [list 1]
	} elseif {[regexp {^BALLS.*} $action]} {
		# Netballs bet
		if { $float != "" && $value < "$float"} {
			log 10 "No match for $action"
			return [list 0]
		} else {
			log 3 "$action matched '$float' & '$char'"
			log 3 "value > float: $float"
			return [list 1]
		}
	} elseif {$action == "BUYMGETN"} {
		set buymgetn_result [ob::games::triggers::check_buymgetn \
					$user_id $trigger_id $ref_type -reset_if_fulfilled 1]
		ob_log::write INFO {buymgetn_result = $buymgetn_result}
		
		if {[lindex $buymgetn_result 0] == 1} {
			set fb_stake [lindex $buymgetn_result 1]
			return [list 1 $fb_stake]
		} else {
			return 0
		}
	} elseif {$action == "GAMEBONUSR"} {
		set bonus_rounds_result [ob::games::triggers::check_bonus_round \
					$user_id $trigger_id  -reset_if_fulfilled 1]
		ob_log::write INFO {bonus_rounds_result = $bonus_rounds_result}
		return $bonus_rounds_result
	} elseif {$action == "BBAR"} {
		if {$ref_type == "FOG"} {
			log 10 "matched BBAR"
			return [list 1]
		} else {
			return [list 0]
		}
	} elseif {$action == "EXP"} {
		if {$ref_type == "EXP"} {
			log 10 "matched EXP"
			return [list 1]
		} else {
			return [list 0]
		}
	} elseif {$action == "FIRSTGAME"} {

		if {$ref_type == "FOG"} {
			# check that no other games have been played in this group
			if [catch {set res [tb_db::tb_exec_qry fb_gp_has_game_group_been_played_before $user_id $trigger_id]} msg] {
				ob::log::write ERROR  "Failed to run fb_gp_has_game_group_been_played_before $msg"
				return [list 0]
			}


			set nrows [db_get_nrows $res]
			if {$nrows == 0} {
				tb_db::tb_close $res
				ob::log::write ERROR  "ERROR! Should have found at least one row for fb_gp_has_game_group_been_played_before"
				return [list 0]
			} elseif {$nrows >= 2} {
				log 10 "Another game in the group has been played"
				tb_db::tb_close $res
			} else {
				set num_plays [db_get_col $res num_plays]
				if {$num_plays == 1} {
					log 1 "FIRSTGAME satisfied"
					tb_db::tb_close $res
					return [list 1]
				}
				log 10 "FIRSTGAME not satisfied.  Game has been played $num_plays times"
				tb_db::tb_close $res
				return [list 0]
			}
			log 10 "FIRSTGAME not satisfied"
			return [list 0]

		} elseif {$ref_type == "SNG"} {

			# run the query
			if {[catch {
				set res [tb_db::tb_exec_qry\
					fb_gp_sng_has_game_group_been_played_before\
					$user_id $trigger_id]
			} msg]} {
				ob::log::write ERROR {Failed to run\
					fb_gp_sng_has_game_group_been_played_before. $msg}
				return [list 0]
			}

			# if there exist rows, it means that the customer *has* played game
			# in this group type previously.
			set nrows [db_get_nrows $res]
			tb_db::tb_close $res

			# return a positive result (1) if no rows found
			if {$nrows == 0} {
				ob::log::write INFO {FIRSTGAME satisfied}
				return [list 1]
			}

			# rows were found, so FIRSTGAME not satisfied
			ob::log::write INFO {FIRSTGAME not satisfied}
			return [list 0]

		}; # if ref_type == SNG


	} elseif {$action == "GAMESSPEND"} {
		return [ob::games::triggers::check_gamesspend $user_id \
		 				$trigger_id -reset_if_fulfilled 1]
	} elseif {$action == "PROMO"} {
		if {[string toupper $promo_code] == $trg_promo_code} {
			log 3 "PROMO matched"
			return [list 1]
		}
		log 3 "PROMO didn't match: $promo_code!=$trg_promo_code"
		return [list 0]
	} elseif {$action == "OFFER"} {
		# Note that we shouldn't actually get here, the offer triggers
		# are being fulfilled directly in check_local
		# when an offer has been claimed.
		return [list 0]
	} else {
		# should not get here
		log 1 "No match for $action"
		return [list 0]
	}

	catch {tb_db::tb_close $rs}
}


# Gets a lists, containing pairs one of the levels and ids of a trigger. These
# are grouped by the level.
#
# Example:
#    % _get_trigger_levels 234
#    {CLASS 1 EVENT 2656 TYPE 34 TYPE 67}
#
#   trigger_id - trigger id
#   returns    - a list
#
proc OB_freebets::_get_trigger_levels {trigger_id} {

	set trigger_levels [list]

	set rs [tb_db::tb_exec_qry fb_trigger_levels $trigger_id]

	set nrows [db_get_nrows $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		set level [db_get_col $rs $r level]
		set id    [db_get_col $rs $r id]

		log 10 "Got trigger level $level, $id"

		lappend trigger_levels $level $id
	}

	db_close $rs

	return $trigger_levels
}

proc OB_freebets::_get_amount_staked {
	arch
	trigger_id
	cust_id
	ccy_code
} {
	if {[lsearch [OT_CfgGet GAME_ARCH_SUPPORTED {}] $arch] == -1} {
		return 0
	}

	set rs [tb_db::tb_exec_qry fb_gp_get_cust_stake_amt_$arch\
			$trigger_id $cust_id $ccy_code ]

	# if num rows returned is not one, then some erroe occured
	set nrows [db_get_nrows $rs]
	if {$nrows != 1} {
		error "$arch amount staked query returned $nrows\
		rows. It should have returned only one."
	}

	# only one row in rs, so it is valid to reference the first
	set amount_staked [db_get_col $rs 0 amount_staked]

	catch {tb_db::tb_close $rs}

	return $amount_staked
}

# check_for_first_action
#
# checks whether the action specified is the first of its type on the customer's
# account
#
# user_id        - customer user id
# action_name    - the action name we are checking for (defined in tCustStatsAction)
# channel_strict - are we checking on a per channel basis or across all channels
# source         - the channel on which the action occurred
#

proc OB_freebets::check_for_first_action {
	user_id
	action_name
	channel_strict
	source
	ref_id
} {

	# will only be used if USE_CUST_STATS is 1 - ie we are using tCustStats

	log 10 "check_for_first_action $user_id \
	                              $action_name \
	                              $channel_strict \
	                              $source \
	                              $ref_id"

	if {$channel_strict == "N"} {
		set source {%}
	}

	if {[catch {
		set rs [tb_db::tb_exec_qry check_for_first_action $user_id $source $ref_id $action_name]
	} msg]} {
		log 1 "failed to execute check_for_first_action: $msg"
		return 0
	}

	set nrows [db_get_nrows $rs]

	if {$nrows > 0} {
		# action has already occured
		log 10 "Action $action_name not first"
		db_close $rs
		return 0
	}

	# no previous action of this type found
	log 10 "Action $action_name is first"
	db_close $rs
}

#
# Check channel strictness for a trigger
#

proc OB_freebets::check_channels {user_id channels_thru channel_strict source} {

	# deprecated by new procedure OB_freebets::check_for_first_action
	# uses old method of tCustomerFlag for storing first bets and deps

	set channels_thru [fb_get_cust_flag $user_id $channels_thru]

	log 20 {check_channels:: channels_thru: $channels_thru}

	if {$channel_strict == "Y"} {
		if {[string first $source $channels_thru] != -1} {
			return 0
		}
	} else {
		if {$channels_thru != ""} {
			return 0
		}
	}

	#
	# Seems to pass all checks

	return 1
}

#
# Fufill a trigger, and claim an offer if all triggers fulfilled.
# Inserts a row into tCalledTrigger, then sees if all triggers
# have been fulfilled for that offer.
#
# trigger_id      - tTrigger.trigger_id
# offer_id        - tTrigger.offer_id
# user_id         - customer id
# ref_id          - id of bet that fulfilled trigger
# ref_type        - bet type that fulfilled trigger
# rank            - order of this trigger (tTrigger.rank)
# action_date     - date of action that fulfilled trigger
# value           - value of deposit/bet etc
# source          - where action was performed

proc OB_freebets::fulfill_trigger {trigger_id offer_id user_id ref_id ref_type rank action_date {value 0} {source "I"} {in_db_trans 0}} {
	global FB_OFFERS_ARR
	global CLAIMED_OFFERS

	log 10 "fulfill_trigger called with: '$trigger_id', '$offer_id', '$user_id', '$ref_id', '$ref_type' ,'$rank', '$action_date', '$value'"
	# Create a called trigger for this customer

	if [catch {set rs [tb_db::tb_exec_qry fb_create_called_trigger \
				$offer_id \
				$trigger_id \
				$user_id \
				$rank \
				$value]} msg] {
		log 1 "Could not create called trigger $trigger_id: $msg"
		return 0
	}

	set called_trigger_id [db_get_coln $rs 0]

	catch {tb_db::tb_close $rs}

	# For each token we redeem we need to make sure that this doesn't get
	# picked up again in the cache
	incr FB_OFFERS_ARR($user_id,$offer_id,$trigger_id,num_triggered)
	if {$FB_OFFERS_ARR($user_id,$offer_id,unlimited_claims) == "N" &&
	    ($FB_OFFERS_ARR($user_id,$offer_id,$trigger_id,num_triggered) >=
	     $FB_OFFERS_ARR($user_id,$offer_id,max_claims))} {
		#remove this trigger from the list
		set trigger_idx [lsearch $FB_OFFERS_ARR($user_id,$offer_id,trigger_ids) $trigger_id]

		if {$trigger_idx != -1} {
			set FB_OFFERS_ARR($user_id,$offer_id,trigger_id) [lreplace $FB_OFFERS_ARR($user_id,$offer_id,trigger_ids) $trigger_idx $trigger_idx]
		}
	}

	# Check for unfulfilled triggers for this offer

	if [catch {set rs [tb_db::tb_exec_qry fb_outstanding_triggers \
				$offer_id \
				$user_id ]} msg] {
		log 1 "Could not get outstanding triggers: $msg"
		return 0
	}

	if {[db_get_nrows $rs] == 0} {
		# No outstanding triggers, claim this offer.
		log 3 "Claiming offer $offer_id"

		if {! [claim_offer $user_id $offer_id $called_trigger_id $ref_id $ref_type] } {
			catch {tb_db::tb_close $rs}
			return 0
		}

		log 1 "Adding offer_id $offer_id to Claimed Offers"

		# Add the offer to the claimed offers list
		lappend CLAIMED_OFFERS $offer_id

		if {[OT_CfgGet ENABLE_FREEBET_REFERRALS "FALSE"] == "TRUE"} {
			# check if offer claimed was a referee offer
			if [catch {set r [tb_db::tb_exec_qry fb_check_for_referee \
								  $offer_id ]} msg] {
				log 1 "Could not check for referee triggers for offer $offer_id: $msg"
				return 0
			}

			set nrows [db_get_nrows $r]
			tb_db::tb_close $r

			if {$nrows > 0} {
				# we have a referee trigger on the offer
				log 10 "Referee trigger on the offer so claim matching referral offer...."
				# need to retrieve the cust_id and aff_id of the user who referred this customer

				if [catch {set r [tb_db::tb_exec_qry fb_get_referral_cust \
									  $user_id ]} msg] {
					log 1 "Could not get referral cust_id for user $user_id: $msg"
					return 0
				}

				set ref_user_id	[db_get_col $r flag_value]
				tb_db::tb_close $r

				if {$ref_user_id == ""} {
					log 1 "No referral cust id could be retrieved. aborting referral claim attempt..."
					return 0
				}

				if [catch {set r [tb_db::tb_exec_qry fb_get_referral_aff \
									  $ref_user_id ]} msg] {
					log 1 "Could not get referral aff for user $ref_user_id: $msg"
					return 0
				}

				set ref_aff_id	[db_get_col $r aff_id]
				tb_db::tb_close $r


				# and the offer id and trigger id of the referral offer's referral trigger
				# what joy!!!

				if [catch {set r [tb_db::tb_exec_qry fb_get_referral_offer \
									  $offer_id ]} msg] {
					log 1 "Could not get referral offer for offer $offer_id: $msg"
					return 0
				}

				set ref_offer_id [db_get_col $r offer_id]
				set ref_trigger_id [db_get_col $r trigger_id]
				tb_db::tb_close $r

				if {($ref_offer_id != "") && ($ref_trigger_id != "")} {
					# check the max claims for the offer of which the referral trigger is a part
					if [catch {set rs [tb_db::tb_exec_qry get_max_claims $ref_offer_id]} msg] {
						log 1 "Could not get max claims for offer with referral trigger $ref_trigger_id: $msg"
						return 0
					}
					set referral_max_claims [db_get_col $rs max_claims]
					set referral_unlimited_claims [db_get_col $rs unlimited_claims]
					tb_db::tb_close $rs

					# now get the number of times this user
					if [catch {set rs [tb_db::tb_exec_qry num_referral_claims $ref_offer_id $ref_user_id]} msg] {
						log 1 "Could not get max claims for offer with referral trigger $ref_trigger_id: $msg"
						return 0
					}

					set num_referral_claims [db_get_col $rs count]
					tb_db::tb_close $rs

					# check if referrer hasn't claimed referral offer too many time
					# or that the offer can be claimed an unlimited number of times
					log 15 "num_referral_claims = $num_referral_claims | referral_max_claims = $referral_max_claims, referral_unlimited_claims = $referral_unlimited_claims"

					if {$referral_unlimited_claims == "N"  &&
						$num_referral_claims < $referral_max_claims} {
						set ret [OB_freebets::get_check_action_data "REFERRAL" $ref_user_id $source $action_date 0]
						if {$ret == 0} {
							return 0
						}

						set check_trigger_result [check_trigger $ref_user_id "REFERRAL" $ref_trigger_id $ref_aff_id 0 -1 "" "" "" $source "" "" N]

						# now try and try to claim the referral offer for this other user
						if {[lindex $check_trigger_result 0]} {
							# Fulfill trigger, and claim offer
							if {! [fulfill_trigger $ref_trigger_id $ref_offer_id $ref_user_id "" "" "" $action_date 0 $source $in_db_trans]} {
								log 10 "Action did not fulfill referral trigger $ref_trigger_id"
							}
							log 15 "Referral Trigger ID: $ref_trigger_id fulfilled"
						}
					}
				}
			}

		}
	} else {
		log 15 "There are [db_get_nrows $rs] unfulfilled triggers for Offer $offer_id"
	}

	catch {tb_db::tb_close $rs}
	return 1
}

#
# Claim an offer for a user, and create customer tokens
#

proc OB_freebets::claim_offer {user_id offer_id called_trigger_id ref_id ref_type} {

	# Create a claimed offer
	log 10 "claim_offer called with: '$user_id', '$offer_id', '$called_trigger_id', '$ref_id', '$ref_type'"

	# Create tokens for customer
	# This proc returns 0 if the user could be given tokens due to
	# num_tokens_max.

	if [catch {set rs [tb_db::tb_exec_qry fb_create_cust_tokens \
				$offer_id \
				$user_id \
				$called_trigger_id \
				$ref_id \
			    $ref_type \
				]} msg] {
		log 1 "Could not create customer tokens for offer $offer_id: $msg"
		return 0
	}

	# if the tokens were able to be inserted (they may not have been able
	# to be, because of offer.num_tokens_max)

	# due to backwards compatability, if the code gets to here without erroring
	# this should always be true.
	set can_offer_be_claimed 0
	if {[db_get_nrows $rs] != 0} {
		set can_offer_be_claimed 1
	}

	catch {tb_db::tb_close $rs}

	if {$can_offer_be_claimed == 0} {
		log 1 "Offer not claimed because customer cannot be given all tokens (tOffer.num_tokens_max regulates this)."
		return 0
	}

	if [catch {set rs [tb_db::tb_exec_qry fb_create_claimed_offer \
						   $offer_id \
						   $user_id ]} msg] {
		log 1 "Could not create claimed offer $offer_id: $msg"
		return 0
	}

	catch {tb_db::tb_close $rs}

	# set status of records in tcalledtrigger to claimed

	if [catch {set rs [tb_db::tb_exec_qry fb_claim_called_triggers \
				$offer_id \
				$user_id ]} msg] {
		log 1 "Could not claim called triggers for offer id $offer_id: $msg"
		return 0
	}

	catch {tb_db::tb_close $rs}

	if [catch {set rs [tb_db::tb_exec_qry fb_check_offer_completion_msg \
						   $offer_id]} msg] {
		log 1 "Could not retrieve offer completion message for offer $offer_id: $msg"
		return 0
	} elseif {[set completion_msg_id [db_get_coln $rs 0]] != ""} {
		if [catch {set rs [tb_db::tb_exec_qry fb_insert_offer_completion_msg_for_cust \
				$completion_msg_id \
				$user_id]} msg] {
			log 1 "Could not insert offer completion message id: $completion_msg_id into the queue of customer $cust_id : $msg"
			return 0
		}
	}
	return 1
}

# Retrieve FreeBets offers & tokens
proc OB_freebets::get_cust_freebets {user_id {aff_id ""}} {
	global LOGIN_DETAILS

	# Note that the % signs are around [OT_CfgGet CHANNEL I]
	# to make the query work
	if [catch {set OffRS [tb_db::tb_exec_qry fb_cust_offers \
			    $user_id \
				"%[OT_CfgGet CHANNEL I]%" \
				$user_id \
				$user_id \
				$aff_id \
				$aff_id \
				$aff_id \
				$aff_id ]} msg] {
		log 1 "Could not retrieve unclaimed offer: $msg"
		return 0
	}

	bind_offers $OffRS

	if [catch {set TokRS [tb_db::tb_exec_qry fb_cust_tokens $user_id $user_id]} msg] {
		log 1 "Could not retrieve tokens: $msg"
		return 0
	}

	acct_bind_tokens $TokRS

	return [list $OffRS $TokRS ]
}


#
# Display valid tokens for this id.  Can be a bet id, or external game id
#

proc OB_freebets::tokens_for_bet {ids {type "SPORTS"}} {
	global LOGIN_DETAILS

	log 20 "finding tokens for ev_ocs: $ids"

	# We need to blart out a list of arguments for tb_exec_qry,
	# we have 20 place-holders for selection ids, need to pad out id list
	# with -1's, and generate a query string.

	# We're assuming we have no more than 20 selections, bail out if there's more .
	set noIds [llength $ids]
	if {$noIds >= 20} {
		log 1 "FREEBETS: tokens_for_bet - $noIds selections passed in"
		return 0
	}

	for {set i $noIds} {$i < 20} {incr i} {
		lappend ids -1
	}

	set qry [concat {tb_db::tb_exec_qry \
				fb_bet_tokens \
				$LOGIN_DETAILS(USER_ID) \
				$type } \
				$ids \
				$ids \
				$type \
				$ids \
				$ids \
				$ids \
				$ids \
				$ids \
				$ids \
				$ids \
				$ids \
				$ids \
				$ids \
				$ids ]

	if [catch {set rs [eval $qry]} msg] {
		log 1 "type is: $type"
		log 1 "query is: $qry"
		log 1 "Could not retrieve valid tokens: $msg"
		return 0
	}

	bind_tokens $rs

	catch {tb_db::tb_close $rs}
}


# =================================================================
# Proc        : OB_freebets::tokens_for_bet_using_bsel
# Description : Gets info from BSEL and FREEBET_TOKENS to determine which
#               of the current selns in BSEL can be used with each of the customers
#               freebet tokens
#
#               Appends the following pieces of info to each freebet
#               in FREEBET_TOKENS
#                  valid_ids - list of ev_oc_ids which can be bet against using the token
#                  valid_sks - list of sk's in BSEL which have a relevant ev_oc_id
#
#               Assumes get_cust_freebets has already
#               been called to set up FREEBET_TOKENS and BSEL exists
#               containing event hierarchy information.
#
# Inputs      : sks - the selection keys to look for selections in in BSEL
# Outputs     : all output is put in
# Author      : sluke
# =================================================================
proc OB_freebets::tokens_for_bet_using_bsel {sks} {
	global FREEBET_TOKENS
	global BSEL

	set num_valid_tokens 0
	for {set i 0} {$i < $FREEBET_TOKENS(NumTokens)} {incr i} {
		set FREEBET_TOKENS($i,valid_ids) [list]
		set FREEBET_TOKENS($i,valid_sks) [list]

		if {$FREEBET_TOKENS($i,redemp_bet_level)=="ANY" || \
			($FREEBET_TOKENS($i,redemp_bet_level)!="XGAME" && $FREEBET_TOKENS($i,redemp_bet_id) != "" && $FREEBET_TOKENS($i,redemp_bet_type)!="")} {

			add_matches $sks $i

		} elseif {$FREEBET_TOKENS($i,redemp_bet_level)=="SELECTION" && $FREEBET_TOKENS($i,redemp_bet_id) !=""} {

			add_matches $sks $i $FREEBET_TOKENS($i,redemp_bet_id) ev_oc_id

		} elseif {$FREEBET_TOKENS($i,redemp_bet_level)=="EVENT"} {
			if {$FREEBET_TOKENS($i,redemp_bet_id) !=""} {

				add_matches $sks $i $FREEBET_TOKENS($i,redemp_bet_id) ev_id

			} elseif {$FREEBET_TOKENS($i,redemp_bet_type)!=""} {

				add_matches $sks $i $FREEBET_TOKENS($i,redemp_bet_type) ev_sort
			}
		} elseif {$FREEBET_TOKENS($i,redemp_bet_level)=="MARKET"} {
			if {$FREEBET_TOKENS($i,redemp_bet_id) != ""} {

				add_matches $sks $i $FREEBET_TOKENS($i,redemp_bet_id) ev_mkt_id

			} elseif {$FREEBET_TOKENS($i,redemp_bet_type)!=""} {

				add_matches $sks $i $FREEBET_TOKENS($i,redemp_bet_type) mkt_sort
			}
		} elseif {$FREEBET_TOKENS($i,redemp_bet_level)=="TYPE" && $FREEBET_TOKENS($i,redemp_bet_id) != ""} {

			add_matches $sks $i $FREEBET_TOKENS($i,redemp_bet_id) ev_type_id

		} elseif {$FREEBET_TOKENS($i,redemp_bet_level)=="CLASS"} {
			if {$FREEBET_TOKENS($i,redemp_bet_id) != ""} {

				add_matches $sks $i $FREEBET_TOKENS($i,redemp_bet_id) ev_class_id

			} elseif {$FREEBET_TOKENS($i,redemp_bet_type)!=""} {

				add_matches $sks $i $FREEBET_TOKENS($i,redemp_bet_type) category
			}
		} elseif {$FREEBET_TOKENS($i,redemp_bet_level)=="COUPON"} {
			if {$FREEBET_TOKENS($i,redemp_bet_id) != ""} {
				set j 0
				set ev_oc_ids [list]
				foreach sk $BSEL(sks) {
					if {$sk==0} {continue}
					lappend ev_oc_ids $BSEL($sk,0,0,ev_oc_id)
					incr j
				}
				#pad it out with -1's if there are <20 selns
				for {} {$j < 20} {incr j} {lappend ev_oc_ids -1}
				set rs [db_exec_qry get_ev_oc_ids_for_coupon $FREEBET_TOKENS($i,redemp_bet_id) $ev_oc_ids]

				for {set j 0} {$j < [db_get_nrows $rs]} {incr j} {
					lappend FREEBET_TOKENS($i,valid_ids) [db_get_col $rs $j ev_oc_id]
				}
			}
		}
	}

}


# =================================================================
# Proc        : OB_freebets::add_matches
# Description : To be used by token_for_bet_using_bsel.
#               Scans through sks,legs and parts of BSEL to find if there
#               are matches with the values stored for the field supplied
#               and the id associated with a token.
#               Puts ev_oc_id and sk info of successful matches in FREEBET_TOKENS
# Inputs      : sks - selection keys in BSEL to look through
#               fb_idx - the index in FREEBET_TOKENS of the token currently being matched
#               id - redemp_bet_id, can be empty string if looking at an ANY token
#               field - field in BSEL to compare to id, can be "" if looking at an ANY token
# Outputs     :
# Author      : sluke
# =================================================================
proc OB_freebets::add_matches {sks fb_idx {id ""} {field ""}}  {

	global FREEBET_TOKENS
	global BSEL

	foreach sk $sks {
		for {set l 0} {$l < $BSEL($sk,num_legs)} {incr l} {
			for {set p 0} {$p < $BSEL($sk,$l,num_parts)} {incr p} {
				if {$id=="" || $BSEL($sk,$l,$p,$field) == $id} {
					if {[lsearch -exact $FREEBET_TOKENS($fb_idx,valid_ids) $BSEL($sk,$l,$p,ev_oc_id)] == -1} {
						lappend FREEBET_TOKENS($fb_idx,valid_ids) $BSEL($sk,$l,$p,ev_oc_id)
					}
					if {[lsearch -exact $FREEBET_TOKENS($fb_idx,valid_sks) $sk] == -1} {
						lappend FREEBET_TOKENS($fb_idx,valid_sks) $sk
					}
					break
				}
			}
		}
	}

}


#
# Bind up a token result set.
#

proc OB_freebets::bind_tokens {rs} {

	global FREEBET_TOKENS LOGIN_DETAILS

	catch {unset FREEBET_TOKENS}

	tpSetVar NumTokens [db_get_nrows $rs]
	log 10 "Number of Freebet tokens: [db_get_nrows $rs]"

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		set FREEBET_TOKENS($i,cust_token_id) [db_get_col $rs $i cust_token_id]
		set FREEBET_TOKENS($i,token_id) [db_get_col $rs $i token_id]
		set FREEBET_TOKENS($i,offer_name) [db_get_col $rs $i offer_name]
		set FREEBET_TOKENS($i,value) [db_get_col $rs $i value]
		set FREEBET_TOKENS($i,nice_value) [print_ccy [db_get_col $rs $i value] $LOGIN_DETAILS(CCY_CODE)]
		set FREEBET_TOKENS($i,creation_date) [db_get_col $rs $i creation_date]
		set FREEBET_TOKENS($i,expiry_date) [db_get_col $rs $i expiry_date]
	}
	tpBindVar CustTokenID FREEBET_TOKENS cust_token_id token_idx
	tpBindVar TokenID FREEBET_TOKENS token_id token_idx
	tpBindVar TokenOfferName FREEBET_TOKENS offer_name token_idx
	tpBindVar TokenValue FREEBET_TOKENS value token_idx
	tpBindVar TokenNiceValue FREEBET_TOKENS nice_value token_idx
	tpBindVar TokenCreateDate FREEBET_TOKENS creation_date token_idx
	tpBindVar TokenExpiry FREEBET_TOKENS expiry_date token_idx

}
#
# Bind up a token result set.
#

proc OB_freebets::acct_bind_tokens {rs} {

	global FREEBET_TOKENS LOGIN_DETAILS

	if {[info exists FREEBET_TOKENS]} {
		unset FREEBET_TOKENS
	}

	tpSetVar NumTokens [db_get_nrows $rs]
	set FREEBET_TOKENS(NumTokens) [db_get_nrows $rs]
	log 10 "Number of Freebet tokens: [db_get_nrows $rs]"

	set last_token_id "-1"
	set last_redemp_name ""

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {

		set FREEBET_TOKENS($i,token_id) 		[db_get_col $rs $i token_id]
		set FREEBET_TOKENS($i,offer_name) 		[db_get_col $rs $i offer_name]
		set FREEBET_TOKENS($i,nice_value) 		[print_ccy [db_get_col $rs $i value]]
		set FREEBET_TOKENS($i,creation_date) 	[db_get_col $rs $i creation_date]
		set FREEBET_TOKENS($i,redemp_name) 		[db_get_col $rs $i name]
		set FREEBET_TOKENS($i,value_num) 		[db_get_col $rs $i value]
		set FREEBET_TOKENS($i,cust_token_id) 	[db_get_col $rs $i cust_token_id]
		#put in global, but not bound up for display
		set FREEBET_TOKENS($i,redemp_id)        [db_get_col $rs $i redemption_id]
		set FREEBET_TOKENS($i,redemp_bet_level) [db_get_col $rs $i bet_level]
		set FREEBET_TOKENS($i,redemp_bet_type)  [db_get_col $rs $i bet_type]
		set FREEBET_TOKENS($i,redemp_bet_id)    [db_get_col $rs $i bet_id]
		set FREEBET_TOKENS($i,adhoc_redemp_id)  [db_get_col $rs $i adhoc_redemp_id]

		set current_token_id 	[db_get_col $rs $i token_id]
		set current_redemp_name	[db_get_col $rs $i name]

		if {($current_token_id == $last_token_id) && ($current_redemp_name != $last_redemp_name)} {

			set FREEBET_TOKENS($i,value) ""
			set FREEBET_TOKENS($i,expiry_date) ""
			set FREEBET_TOKENS($i,short_expiry_date) ""

		} else {

			set FREEBET_TOKENS($i,value) [print_ccy [db_get_col $rs $i value] $LOGIN_DETAILS(CCY_CODE)]
			set FREEBET_TOKENS($i,expiry_date) [db_get_col $rs $i expiry_date]
			set FREEBET_TOKENS($i,short_expiry_date) [db_get_col $rs $i short_expiry_date]
		}

		set last_token_id $current_token_id
		set last_redemp_name $current_redemp_name
	}

	tpBindVar CustTokenID      	FREEBET_TOKENS cust_token_id     token_idx
	tpBindVar TokenID 			FREEBET_TOKENS token_id token_idx
	tpBindVar TokenOfferName 	FREEBET_TOKENS offer_name token_idx
	tpBindVar TokenValue 		FREEBET_TOKENS value token_idx
	tpBindVar TokenNiceValue 	FREEBET_TOKENS nice_value token_idx
	tpBindVar TokenCreateDate 	FREEBET_TOKENS creation_date token_idx
	tpBindVar TokenExpiry 		FREEBET_TOKENS expiry_date token_idx
	tpBindVar TokenShortExpiry 	FREEBET_TOKENS short_expiry_date token_idx
	tpBindVar TokenRedempName 	FREEBET_TOKENS redemp_name token_idx
	tpBindVar TokenValueNum    	FREEBET_TOKENS value_num         token_idx

}

proc OB_freebets::gp_acct_bind_tokens {rs} {

	global FREEBET_GP_TOKENS LOGIN_DETAILS

	if {[info exists FREEBET_GP_TOKENS]} {
		unset FREEBET_GP_TOKENS
	}

	tpSetVar NumTokens [db_get_nrows $rs]
	set FREEBET_GP_TOKENS(NumTokens) [db_get_nrows $rs]
	log 10 "Number of Freebet GP tokens: [db_get_nrows $rs]"

	set last_token_id   "-1"
	set last_gp_game_id ""

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {

		set FREEBET_GP_TOKENS($i,token_id)      [db_get_col $rs $i token_id]
		set FREEBET_GP_TOKENS($i,offer_name)    [db_get_col $rs $i offer_name]
		set FREEBET_GP_TOKENS($i,nice_value)    [print_ccy [db_get_col $rs $i value]]
		set FREEBET_GP_TOKENS($i,creation_date) [db_get_col $rs $i creation_date]
		set FREEBET_GP_TOKENS($i,game_name)     [db_get_col $rs $i name]
		set FREEBET_GP_TOKENS($i,game_arch)     [db_get_col $rs $i game_arch]
		set FREEBET_GP_TOKENS($i,value_num)     [db_get_col $rs $i value]
		set FREEBET_GP_TOKENS($i,cust_token_id) [db_get_col $rs $i cust_token_id]
		#put in global, but not bound up for display
		set FREEBET_GP_TOKENS($i,gp_game_id)    [db_get_col $rs $i gp_game_id]

		set current_token_id 	[db_get_col $rs $i token_id]
		set current_gp_game_id	[db_get_col $rs $i gp_game_id]

		if {($current_token_id == $last_token_id) && ($current_gp_game_id != $last_gp_game_id)} {

			set FREEBET_GP_TOKENS($i,value) ""
			set FREEBET_GP_TOKENS($i,expiry_date) ""
			set FREEBET_GP_TOKENS($i,short_expiry_date) ""

		} else {

			set FREEBET_GP_TOKENS($i,value) [print_ccy [db_get_col $rs $i value] $LOGIN_DETAILS(CCY_CODE)]
			set FREEBET_GP_TOKENS($i,expiry_date) [db_get_col $rs $i expiry_date]
			set FREEBET_GP_TOKENS($i,short_expiry_date) [db_get_col $rs $i short_expiry_date]
		}

		set last_token_id    $current_token_id
		set last_gp_game_id  $current_gp_game_id
	}
	tpBindVar CustTokenID      FREEBET_GP_TOKENS cust_token_id     token_idx
	tpBindVar TokenID          FREEBET_GP_TOKENS token_id          token_idx
	tpBindVar TokenOfferName   FREEBET_GP_TOKENS offer_name        token_idx
	tpBindVar TokenValue       FREEBET_GP_TOKENS value             token_idx
	tpBindVar TokenNiceValue   FREEBET_GP_TOKENS nice_value        token_idx
	tpBindVar TokenCreateDate  FREEBET_GP_TOKENS creation_date     token_idx
	tpBindVar TokenExpiry      FREEBET_GP_TOKENS expiry_date       token_idx
	tpBindVar TokenShortExpiry FREEBET_GP_TOKENS short_expiry_date token_idx
	tpBindVar TokenGameName    FREEBET_GP_TOKENS game_name         token_idx
	tpBindVar TokenGameArch    FREEBET_GP_TOKENS game_arch         token_idx
	tpBindVar TokenValueNum    FREEBET_GP_TOKENS value_num         token_idx

}

#
# Bind up an offer result set.
#

proc OB_freebets::bind_offers {rs} {

	tpSetVar NumOffers [db_get_nrows $rs]

	tpBindTcl OfferId sb_res_data $rs offer_idx offer_id
	tpBindTcl OfferName sb_res_data $rs offer_idx name
	tpBindTcl OfferEndDate sb_res_data $rs offer_idx end_date
	tpBindTcl OfferDesc sb_res_data $rs offer_idx description
}

#
# Check tokens for redemption.  Given a list of selections, or an external game id
# and, a bet cost, and a list of tokens, return an array containg a list of tokens
# for redemption, and their cumulative value
#

proc OB_freebets::validate_tokens {cust_token_ids ids cost {type "SPORTS"}} {
	global LOGIN_DETAILS

	if {[OB_login::ob_is_guest_user]} {
		play_template Guest
		return
	}

	if {[llength $cust_token_ids] == 0} {
		return [list]
	}

	log 3 "==> validate_tokens"
	log 3 "cust tokens  : $cust_token_ids"
	log 3 "cost    		: $cost"
	log 3 "ids     		: $ids"

	set redeemList [list]

	# We need to blart out a list of arguments for tb_exec_qry,
	# we have 20 place-holders for selection ids, need to pad out id list
	# with -1's, and generate a query string.


	# We're assuming we have no more than 20 selections, bail out if there's more .
	set noIds [llength $ids]
	if {$noIds >= 20} {
		log 1 "FREEBETS: tokens_for_bet - $noIds selections passed in"
		return 0
	}

	for {set i $noIds} {$i < 20} {incr i} {
		lappend ids -1
	}

	# Validate each token in request.
	for {set i 0} {$cost > 0 && $i < [llength $cust_token_ids]} {incr i} {

		set cust_token_id [lindex $cust_token_ids $i]

		# Build query
		set qry [concat tb_db::tb_exec_qry \
				fb_validate_token \
				$LOGIN_DETAILS(USER_ID) \
				$cust_token_id \
				$type \
				$ids \
				$ids \
				$type \
				$ids \
				$ids \
				$ids \
				$ids \
				$ids \
				$ids \
				$ids \
				$ids \
				$ids ]


		# Check token valid for selection
		if [catch {set rs [eval $qry]} msg] {
			log 1 "Could not validate cust token $cust_token_id for $type selection $ids: $msg"
			return 0
		}

		set nrows [db_get_nrows $rs]

		if {$nrows == 1} {
			# Valid cust token, add value to total
			set value [db_get_col $rs 0 value]

			# Append to valid list
			set token(id) $cust_token_id

			# If cost is less than value, use cost as amount redeemed.
			if {$cost < $value} {
				set value $cost
			}

			set token(redeemed_val) $value

			lappend redeemList [array get token]

			# Reduce total cost
			set cost [expr "$cost - $value"]
			log 3 "Cust Token $cust_token_id is valid, reducing cost to $cost"
		} else {
			log 10 "Cust Token $cust_token_id is not valid"
		}
	}

	log 8 "returning $redeemList"
	return $redeemList
}

#
# Redeem tokens used for a bet.
#

proc OB_freebets::redeem_tokens {tokens id {type "SPORTS"}} {

	global LOGIN_DETAILS

	if {[OB_login::ob_is_guest_user]} {
		play_template Guest
		return 0
	}

	set tokens_length [llength $tokens]

	if {$tokens_length == 0} {
		return 1
	}

	for {set i 0} {$i < $tokens_length} {incr i} {

		array set token [lindex $tokens $i]
		set cust_token_id $token(id)
		set token_val $token(redeemed_val)

		log 3 "Redeeming cust token $cust_token_id at $token_val for $type bet/sub $id"
		if [catch {set rs [tb_db::tb_exec_qry fb_redeem_token \
							   $LOGIN_DETAILS(USER_ID) \
							   $cust_token_id \
							   $type \
							   $id \
							   $token_val \
							   "N" \
				]} msg] {
			log 1 "Could not redeem cust token $cust_token_id for $type selection $id: $msg"
			return 0
		}
		if {[OB_db::db_garc fb_redeem_token] == 0} {
			log 1 "Tried to redeem a token but couldn't.  Should not get here."
			return 0
		}

	}

	return 1
}



# Redeem a GP token used on a bet
# cust_token_id the customer token id
# system_arch FOG or SNG
# game_id is either cg_id or ug_draw_def_id
# amount is the amount of the token that will be spent on the game
proc OB_freebets::gp_redeem_token {cust_token_id system_arch game_id amount} {

	global LOGIN_DETAILS

	if {[OB_login::ob_is_guest_user]} {
		log 1 "Guest users can't redeem tokens"
		return 0
	}

	if [catch {set rs [tb_db::tb_exec_qry fb_redeem_token \
						   $LOGIN_DETAILS(USER_ID) \
						   $cust_token_id \
						   $system_arch \
						   $game_id \
						   $amount \
						   "Y" \
						  ]} msg] {
		log 1 "Could not redeem gp customer token $cust_token_id: $msg"
		return 0
	}

	if {[OB_db::db_garc fb_redeem_token] == 0} {
			log 1 "Tried to redeem a gp token but couldn't.  Should not get here."
			return 0
	}

	return 1
}


#
#
# Returns 1 if successful
# Returns 0 if failed
#
proc OB_freebets::bind_freebets_tokens_SNG {} {
	global TOKENS
	global LOGIN_DETAILS

	# check whether the customer is logged in or not.
	if {[OB_login::ob_is_guest_user]} {
		ob::log::write ERROR {Can't get freebet tokens for guest user}
		return 0
	}

	# this will be required in the sql query to get the freebet tokens
	set cust_id $LOGIN_DETAILS(USER_ID)

	# execute query fb_gp_get_freebet_tokens_SNG
	if {[catch {
		set rs [tb_db::tb_exec_qry fb_gp_get_freebet_tokens_SNG $cust_id]
	} msg]} {
		ob::log::write ERROR {Couldn't execute query to get tokens $msg}
		return 0
	}

	# this is where things get complicated.
	# An array structure is needed of the form:
	# TOKENS(t_idx,cust_token_id)
	# TOKENS(t_idx,value)
	# TOKENS(t_idx,single_use)
	# TOKENS(t_idx,expiry_date)

	# for each customer token, (effectively for each value of t_idx)
	# we have one or more limits
	# TOKEN(t_idx,l_idx,ug_type_grp_code)
	# TOKEN(t_idx,l_idx,min_stake)
	# TOKEN(t_idx,l_idx,max_stake)

	# so it might be useful to store
	# TOKEN(t_idx,no_of_limits)

	array unset TOKENS

	set nrows [db_get_nrows $rs]

	set token_counter 0
	set limit_counter 0
	set last_token_id -1

	# these lists are for convenience (less typing means less chance of erroe)
	set token_cols [list cust_token_id value single_use expiry_date]
	set limit_cols [list ug_type_grp_code min_stake max_stake]

	for {set i 0} {$i < $nrows} {incr i} {

		# get the details
		foreach col $token_cols {
			set $col [db_get_col $rs $i $col]
		}

		# on the first iteration of the loop, last_token_id will be -1
		if {$last_token_id == -1} {
			set last_token_id $cust_token_id
		}

		# now we can safely check whether this cust_token_id is different to
		# the last
		if {$cust_token_id != $last_token_id} {
			set last_token_id $cust_token_id

			# move on to the next token counter
			incr token_counter

			# obviously we are on the first limit (for the new token)
			set limit_counter 0
		}

		# set the token details in the array
		# use [set $col] because it is safer than [subst $$col] (the latter
		# could run a command, nasty)
		foreach col $token_cols {
			set TOKENS($token_counter,$col) [set $col]
		}

		# now set the limit details
		foreach col $limit_cols {
			set $col [db_get_col $rs $i $col]
			set TOKENS($token_counter,$limit_counter,$col) [set $col]
		}

		# now update the limit counter and the number of limits
		incr limit_counter
		set TOKENS($token_counter,no_of_limits) $limit_counter
	}

	# again this is for convenience
	lappend token_cols no_of_limits

	# do some binding
	foreach col $token_cols {
		tpBindVar $col TOKENS $col token_idx
	}

	foreach col $limit_cols {
		tpBindVar $col TOKENS $col token_idx limit_idx
	}

	tpSetVar num_tokens [expr {$token_counter + 1}]

	ob::log::write INFO {num_tokens = [tpGetVar num_tokens]}

	ob::log::write_array INFO TOKENS

	# all done
	return 1
}

#
# returns an empty list if successful
# returns a list with 3 items if successful
#   {min_stake max_stake token_value}
#
#
proc OB_freebets::get_token_amounts_SNG {cust_token_id ug_type_grp_code} {
	global LOGIN_DETAILS

	# check whether the customer is logged in or not.
	if {[OB_login::ob_is_guest_user]} {
		ob::log::write ERROR {Can't check freebet limits for guest user}
		return [list ]
	}

	# this will be required to work out the customer currency code
	set cust_id $LOGIN_DETAILS(USER_ID)

	# speaking of customer currency code
	set ccy_code [get_cust_ccy_code $cust_id]

	# if the ccy_code was 0, there was an erroe
	if {$ccy_code == 0} {
		ob::log::write ERROR {Couldn't get currency code}
		return [list ]
	}

	# all fine so far, so execute a query
	if {[catch {
		set rs [tb_db::tb_exec_qry fb_gp_get_token_limits_SNG \
			$cust_token_id \
			$ccy_code \
			$ug_type_grp_code\
		]
	} msg]} {
		ob::log::write ERROR {Couldn't execute query to get limits for SNG \
			games $msg}
		return [list ]
	}

	# get the number of rows
	set nrows [db_get_nrows $rs]

	# if there are no rows in the query returned, then the customer token
	# could not be validated
	if {$nrows == 0} {
		ob::log::write ERROR {Couldn't validate token, because no rows were\
			returned from the query fb_gp_get_token_limits_SNG}
		return [list ]
	}

	# only one row should be returned, otherwise something odd has happened
	if {$nrows != 1} {
		ob::log::write ERROR {Something really odd happened here, only one row\
			should have been returned}
		return [list ]
	}

	# add the revelant columns from the result set into a list
	set result [list ]
	foreach column {min_stake max_stake value} {
		set val [db_get_col $rs 0 $column]

		# return -1 if there is no value ( a blank )
		if {$val == ""} {
			set val -1
		}

		lappend result $val
	}

	# all done!
	return $result
}

#
# Finds out if there are selections that match the criteria of
# bet_level and bet_id
#
#   level  - bet level (CLASS, TYPE, EVENT, MARKET, SELECTION)
#   ids    - list of ids to check
#   evocs  - list of evocs in bet
#   return - if any of the evocs are in range
#
proc OB_freebets::check_ev_oc_in_range {level ids evocs} {

	log 10 "Matching bet level level=$level, ids=$ids, evocs=$evocs"

	# we already know the ev ocs in this bet, so we
	# don't need to hit the database
	if {$level == "SELECTION"} {
		foreach evoc $evocs {
			if {[lsearch $ids $evoc] >= 0} {
				log 10 "Matches evoc=$evoc"
				return 1
			}
		}
		return 0
	}


	# none of the queries can handle more than 20 ids or selections
	if {[llength $ids] > 20} {
		log 5 "Can't handle more than 20 ids."
		set ids [lrange $ids 0 19]
	}

	if {[llength $evocs] > 20} {
		log 5 "Can't handle more than 20 selections."
		set evocs [lrange $evocs 0 19]
	}

	# pad each list with -1 (not a valid id)
	while {[llength $ids] < 20} {
		lappend ids -1
	}

	while {[llength $evocs] < 20} {
		lappend evocs -1
	}


	# the qrys to use for each type
	array set QRYS {
		MARKET fb_selection_in_market
		EVENT  fb_selection_in_event
		TYPE   fb_selection_in_type
		CLASS  fb_selection_in_class
	}

	# a number of queries won't be available - basically and type of game
	if {![info exists QRYS($level)]} {
		log 1 "Failed to find a query for level $level"
		return 0
	}


	if {[catch {
		set rs [eval tb_db::tb_exec_qry $QRYS($level) $ids $evocs]
	} msg]} {
		log 1 "Failed check query $qry: $msg"
		return 0
	}

	set nrows [db_get_nrows $rs]

	db_close $rs

	log 10 "Match nrows=$nrows"

	return $nrows
}

###########################################################
## Handles the checking and redemption of a freebet voucher
###########################################################
proc OB_freebets::redeem_voucher {voucher} {

	global LOGIN_DETAILS
	global REDEEM_VOUCHER

	set voucher_id [string trimleft [string range $voucher 0 7] "0"]
	set enc_voucher_id [string range $voucher 8 23]

	if [catch {set rs [tb_db::tb_exec_qry fb_get_voucher_data $voucher_id]} msg] {
		log 1 "Could not get data for voucher $voucher_id: $msg"
		err_add [ml_printf VOUCHER_NO_DATA]
		return 0
	}

	set nrows [db_get_nrows $rs]

	if {$nrows != "1"} {
		log 1 "Only 1 row was not retrieved so cannot continue."
		err_add [ml_printf VOUCHER_NO_DATA]
		return 0
	}

	set voucher_key	[db_get_col $rs 0 voucher_key]
	set type_code 	[db_get_col $rs 0 type_code]
	set cust_id 	[db_get_col $rs 0 cust_id]
	set redeemed 	[db_get_col $rs 0 redeemed]
	set trigger_id	[db_get_col $rs 0 trigger_id]
	set valid_from	[db_get_col $rs 0 valid_from]
	set valid_to	[db_get_col $rs 0 valid_to]

	tb_db::tb_close $rs

	# check for valid dates

	set curr_time_secs [clock seconds]

	if {$valid_from != ""} {
		# check valid from date
		set valid_from_secs	[clock scan $valid_from]

		if {!($valid_from_secs <= $curr_time_secs)} {
			# voucher is not yet valid
			log 15 "Voucher is not yet valid"
			err_add [ml_printf VOUCHER_NOT_YET_VALID]
			return 0
		}
		log 15 "Voucher passes valid_from check"
	} else {
		log 15 "Voucher doesnt need valid_from check"
	}

	if {$valid_to != ""} {
		# check valid to date
		set valid_to_secs	[clock scan $valid_to]

		if {!($curr_time_secs <= $valid_to_secs)} {
			# voucher is past valid
			log 15 "Voucher is past valid"
			err_add [ml_printf VOUCHER_PAST_VALID]
			return 0
		}
		log 15 "Voucher passes valid_to check"
	} else {
		log 15 "Voucher doesnt need valid_to check"
	}

	# voucher has valid dates so continue

	set unenc_voucher_id [string trimleft [voucher_decrypt $enc_voucher_id $voucher_key] "0"]

	log 15 "voucher id = $voucher_id"
	log 15 "unencypted voucher id = $unenc_voucher_id"

	# check whether decypted voucher id matches the voucher id at front of voucher

	if {$unenc_voucher_id != $voucher_id} {

		log 10 "Voucher does not appear valid after decryption."
		err_add [ml_printf VOUCHER_INVALID]
		return 0
	} else {
		# it's all good so go on and process voucher

		if {$cust_id != ""} {
			# check whether the right customer is trying to use the voucher
			if {$LOGIN_DETAILS(USER_ID) != $cust_id} {
				log 10 "Customer's cust_id $LOGIN_DETAILS(USER_ID) does not match voucher's cust_id $cust_id."
				err_add [ml_printf VOUCHER_WRONG_CUST]
				return 0
			}
		}

		if {$redeemed} {
			# voucher has already been used
			log 10 "Voucher $voucher_id has been redeemed already."
			err_add [ml_printf VOUCHER_ALREADY_REDEEMED]
			return 0
		}

		# everything seems ok so fire check_action

		# Grab current affiliate from cookie
		set aff_id [get_cookie AFF_ID]

		set REDEEM_VOUCHER 0

		if {![OB_freebets::check_action VOUCHER $LOGIN_DETAILS(USER_ID) \
						 $aff_id "" "" ""\
						 $type_code \
						 $trigger_id]} {
			log 1 "Check action VOUCHER failed"
			log 1 "cust id 		: $LOGIN_DETAILS(USER_ID)"
			log 1 "aff_id   	: $aff_id"
			log 1 "type_code	: $type_code"
			log 1 "trigger id	: $trigger_id"
			return 0
		}
		if {$REDEEM_VOUCHER} {
			# now need to set the voucher as redeemed
			log 10 "Redeeming the voucher...."
			if [catch {set rs [tb_db::tb_exec_qry fb_redeem_voucher $voucher_id]} msg] {
				log 1 "Could not set to redeemed voucher $voucher_id: $msg"
			}
			return 1
		}
	}
	err_add [ml_printf VOUCHER_NOT_REDEEMED]
	unset REDEEM_VOUCHER
	return 0
}

proc OB_freebets::redeem_promo {cust_id promo_code {source ""}} {

	variable TRIGGER_FULFILLED

	# Grab current affiliate from cookie
	set aff_id [get_cookie [OT_CfgGet AFF_ID_COOKIE AFF_ID]]

	if {[check_action PROMO $cust_id $aff_id "" "" "" "" "" "" "" \
		$promo_code ""] != 1} {
		log 1 "Check_action PROMO failed. Cust_id: ${cust_id}. Promo_code: ${promo_code}"
		return 0
	}
	if {[OT_CfgGet USE_FREEBETS_SERVER 0]} {
		# Freebets server not currently set up to return info
		# don't know if successful or not
		log 3 "Using shared server. Not known if promo code: ${promo_code} triggered"
		return -1
	}
	if {!$TRIGGER_FULFILLED} {
		log 3 "Promo code: ${promo_code} NOT triggered"
		return 0
	}
	log 3 "Promo code: ${promo_code} triggered"
	return 1
}

proc OB_freebets::voucher_decrypt {enc_voucher_id voucher_key} {

	if {[string length $enc_voucher_id] != 16} {
        return ""
    }

	if {[string length $voucher_key] != 8} {
        return ""
    }

    set unenc_voucher_id [blowfish decrypt -hex $voucher_key -hex $enc_voucher_id]
	set unenc_voucher_id [hextobin $unenc_voucher_id]

	return $unenc_voucher_id
}

proc OB_freebets::check_referral {ref_user aff_id {cust_id ""}} {

    global USER_ID

    # If the customer id was passed in use this rather than the global id
    if {$cust_id != ""} {
        set user_id $cust_id
    } else {
        set user_id $USER_ID
    }

    log 10 "About to get cust_id for referred username/accno $ref_user"

    set ref_cust_id 0

    # first try as if its a username

    if [catch {set rs [tb_db::tb_exec_qry fb_ref_get_cust_id $ref_user]} msg] {
		log 2 "Can't get referral cust_id: $msg"
    } else {
		set nrows [db_get_nrows $rs]

		if {$nrows == 1} {
			log 10 "User has been referred by usename $ref_user"
			set ref_cust_id [db_get_col $rs cust_id]
			tb_db::tb_close $rs
		} else {
			tb_db::tb_close $rs
			# ok no username match so try as an account number

			if [catch {set rs [tb_db::tb_exec_qry fb_ref_get_cust_id_acc $ref_user]} msg] {
				log 1 "Can't get referral cust_id: $msg"
			} else {
			    set nrows [db_get_nrows $rs]

			    if {$nrows == 1} {
					log 10 "User has been referred by account number $ref_user"
					set ref_cust_id [db_get_col $rs cust_id]
			    }
			    tb_db::tb_close $rs
			}
		}
    }

    if {$ref_cust_id != 0} {
		log 10 "About to save cust_id $ref_cust_id for referred username/accountno $ref_user"

		fb_set_cust_flag $user_id REF_CUST_ID $ref_cust_id

		# now do the referee freebet action
		check_action "REFEREE" $user_id $aff_id
    }
}

#
# This is a modified version of set_flag from prefs.tcl. It is repeated here for 2
# reasons 1. To run without a logged in user (as is the case with admin screen user
# registration) 2. To run without the db_exec_qry commands (not available under admin)
# Ideally there should be a better way of doing this.
#
proc OB_freebets::fb_set_cust_flag {cust_id flag value} {

        if {$value == ""} {

            if [catch {tb_db::tb_exec_qry fb_flag_delete $cust_id $flag} msg] {
                log 1 "failed to delete flag: $msg"
            }

        } else {

            if [catch {set rs [tb_db::tb_exec_qry fb_flag_select $cust_id $flag]} msg] {
                log 1 "failed to select flag $flag: $msg"
            } else {
                set nrows [db_get_nrows $rs]
                if {$nrows == 1} {
                    set qry fb_flag_update
                } else {
                    set qry fb_flag_insert
                }

                if [catch {tb_db::tb_exec_qry $qry $value $cust_id $flag} msg] {
	                log 1 "failed to insert/update flag: $msg"
                }
                db_close $rs
            }
        }
    }


# Get the value of a flag.
#
#   cust_id  - The customer ID.
#   flag     - The flag's name.
#   returns  - The flag's value.
#
proc OB_freebets::fb_get_cust_flag {cust_id flag} {

	if {[catch {
		set rs [tb_db::tb_exec_qry fb_flag_select $cust_id $flag]
	} msg]} {
		log 1 "failed to select flag: $msg"
		return ""
	}

	set flag_value ""
	set nrows [db_get_nrows $rs]

	if {$nrows == 1} {
		set flag_value [db_get_col $rs 0 flag_value]
	}

	db_close $rs

	return $flag_value
}

#
# Freebets server
#
# Enables freebets to be triggered by non-sportbook events eg. Netballs bets,
# by providing a HTTP wrapper to the check_action proc.
#
# A standalone app server should be configured to act as the freebets server.
#
# This requests are POST requests carrying an XML document with the following form.
#
# NB. The XML is not explicitly validated.
#
# DTD specification
#
#   <!ELEMENT check_action_request (check_action+)>
#   <!ELEMENT check_action (action+)>
#       <!ATTLIST user_id CDATA REQUIRED>
#       <!ATTLIST aff_id CDATA OPTIONAL>
#       <!ATTLIST value CDATA REQUIRED>
#       <!ATTLIST evocs CDATA OPTIONAL>
#       <!ATTLIST sort CDATA OPTIONAL>
#       <!ATTLIST vch_type CDATA OPTIONAL>
#       <!ATTLIST vch_trigger_id CDATA OPTIONAL>
#       <!ATTLIST ref_id CDATA REQUIRED>
#       <!ATTLIST ref_type CDATA REQUIRED>
#       <!ATTLIST source CDATA REQUIRED>
#       <!ATTLIST promo_code CDATA OPTIONAL>
#   <!ELEMENT action (PCDATA)>
#
# Example
#
#   <?xml version="1.0" encoding="UTF-8"?>
#   <check_action user_id="21017358" aff_id="" value="1.0" evocs="128330"
#           sort="" vch_type="" vch_trigger_id="" ref_id="10827" ref_type="SPORTS">
#       <action>BET</action>
#       <action>SPORTSBET</action>
#   </check_action>
#

#
# Freebets server proc
#
# Sends a freebets server check_action request.
#
# xml_msg     - raw xml

proc OB_freebets::check_action_http {xml_msg} {

	log 10 "in check_action_http"

	#Parse the xml message.
	set check_actions [parse_check_action_xml $xml_msg]

	set action_date [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]

	foreach check_action $check_actions {
		foreach {action_list user_id aff_id value evocs sort vch_type vch_trigger_id ref_id ref_type source promo_code} $check_action {}
		# Start the transaction
		tb_db::tb_begin_tran

		log 10 "check_action_local called with: $action_list, $user_id, $aff_id, $value, $evocs, $sort, $vch_type, $vch_trigger_id, $ref_id, $ref_type, $action_date, $source, $promo_code"

		# Check the action.
		set ret_value [check_action_local $action_list \
		                                  $user_id \
		                                  $aff_id \
		                                  $value \
		                                  $evocs \
		                                  $sort \
		                                  $vch_type \
		                                  $vch_trigger_id \
		                                  $ref_id \
		                                  $ref_type \
		                                  $action_date \
		                                  $source \
		                                  $promo_code]

		log 10 "check_action_local ret_value: $ret_value"

		# End the transaction
		if {$ret_value == 0} {
			tb_db::tb_rollback_tran
		} else {
			tb_db::tb_commit_tran
		}
	}
}



#
# Freebets server proc
#
# Sends a freebets server check_action request.
#
# action         - code for what user did, eg REG (register),
#                      VOUCHER (voucher) etc
# user_id        - customer id
# aff_id         - affiliate id
# value          - vlaue of deposit/bet etc
# evocs          - outcome ids associated with action
# sort           - table.sort that the user is betting on
# vch_type       - tTrigger.voucher_type
# vch_trigger_id - tVoucher.trigger_id
# ref_id         - id of bet of action
# ref_type       - bet type of action
# source         - where action came from

proc OB_freebets::check_action_http_req {action user_id aff_id value evocs \
						sort vch_type vch_trigger_id ref_id ref_type source promo_code} {

	log 10 "OB_freebets::check_action_http_req called with \
		'$action', '$user_id', '$aff_id', '$value', \
		'$evocs', '$sort', '$vch_type', '$vch_trigger_id', \
		'$ref_id', '$ref_type', '$source', '$promo_code'"

	package require http

	# Build the request xml message.
	set xml_msg [build_check_action_xml $action $user_id $aff_id $value \
			$evocs $sort $vch_type $vch_trigger_id $ref_id $ref_type $source $promo_code]

	log 15 "xml_msg = $xml_msg"

	set get_url_fail 0

	if {[catch {
		# Send the request.
		set resp_token [http::geturl \
							[OT_CfgGet FREEBETS_SERVER_URL]\
							-timeout [OT_CfgGet FREEBETS_SERVER_TIMEOUT] \
							-type "text/xml" \
							-query $xml_msg]
		upvar #0 $resp_token state

		log 3 "Freebets server response status: $state(http)"
	} msg]} {
		log 1 "Failed to get a reponse from the freebets server: $msg"
		set get_url_fail 1
	}

	# Get the http response code. For a successful request $state(http)
	# will be of the form:
	#
	# HTTP_VERSION HTTP_RESPONSE_CODE HTTP_RESPONSE_MESSAGE
	#
	# For a successful request:
	#
	# HTTP/1.1 200 OK
	set http_response_code [lindex [split $state(http) " "] 1]

	if {$get_url_fail || ($http_response_code != "200")} {
		#If the reqest failed then log the action.
		log 1 "Logging failed freebets http check action."
		log_failed_check_action $action $user_id $aff_id $value $evocs $sort $vch_type $vch_trigger_id $ref_id $ref_type $source
	}
}

#
# Freebets server proc
#
# Parses a freebets server check_action document.
#
# For parameters, see check_action_http_request

proc OB_freebets::log_failed_check_action {action user_id aff_id value evocs sort vch_type \
											   vch_trigger_id ref_id ref_type source promo_code} {
	log 10 "OB_freebets::log_failed_check_action called with \
		'$action', '$user_id', '$aff_id', '$value', \
		'$evocs', '$sort', '$vch_type', '$vch_trigger_id', \
		'$ref_id', '$ref_type', '$source', '$promo_code'"

	# Log the failed action to the database
	if [catch {set off_rs [tb_db::tb_exec_qry fb_log_failed_check_action $action $user_id \
							   $aff_id $value $evocs $sort $vch_type $vch_trigger_id $ref_id $ref_type $source $promo_code]} msg] {
		log 1 "Failed to log failed freebets check action: $msg"
		log 1 "'$action', '$user_id', '$aff_id', '$value', '$evocs', '$sort', '$vch_type', '$vch_trigger_id', '$ref_id', '$ref_type', '$source', '$promo_code'"
	}
}

#
# Freebets server proc
#
# xml_msg - raw xml post

proc OB_freebets::check_action_msg {xml_msg} {

	set message_text "Checking action."

	# build response xml

	dom setResultEncoding [OT_CfgGet XML_ENCODING "UTF-8"]

	set doc           [dom createDocument "shared_server"]
	set sharedserver  [$doc documentElement]

	set resp          [$doc createElement "response"]
	set message       [$sharedserver appendChild $resp]

	set elem          [$doc createElement "respCheckAction"]
	set respAuth      [$message appendChild $elem]

	## message elem
	set elem          [$doc createElement "message"]
	set message_node  [$respAuth appendChild $elem]
	set message_tnode [$doc createTextNode $message_text]
	$message_node appendChild $message_tnode

	return $resp
}



#
# Freebets server proc
# Doesn't appear to do anything except return an xml response, with
# a message text saying its rechecking previously failed actions.
#
# xml_msg - raw xml post

proc OB_freebets::recheck_failed_actions_msg {xml_msg} {

	set message_text "Rechecking failed actions."

	# build response xml

	dom setResultEncoding [OT_CfgGet XML_ENCODING "UTF-8"]

	set doc           [dom createDocument "shared_server"]
	set sharedserver  [$doc documentElement]

	set resp          [$doc createElement "response"]
	set message       [$sharedserver appendChild $resp]

	set elem          [$doc createElement "respRecheckFailed"]
	set respAuth      [$message appendChild $elem]

	## message elem
	set elem          [$doc createElement "message"]
	set message_node  [$respAuth appendChild $elem]
	set message_tnode [$doc createTextNode $message_text]
	$message_node appendChild $message_tnode

	return $resp
}



#
# Freebets server proc.
# Counts the number of freebet check actions in the database that have
# previously failed for whatever reason.
#
# xml_msg - raw xml post

proc OB_freebets::failed_check_actions_count {xml_msg} {

	# Select all of the failed check actions
	if [catch {set rs [tb_db::tb_exec_qry fb_get_failed_check_actions_count]} msg] {
		log 1 "Failed to get failed freebets check actions: $msg"
		return 0
	}

	set count [db_get_col $rs 0 count]
	set message_text "There are ${count} failed check actions in the openbet database."

	# build response xml

	dom setResultEncoding [OT_CfgGet XML_ENCODING "UTF-8"]

	set doc            [dom createDocument "shared_server"]
	set sharedserver   [$doc documentElement]

	set resp           [$doc createElement "response"]
	set message        [$sharedserver appendChild $resp]

	set elem           [$doc createElement "respRecheckFailedCount"]
	set respAuth       [$message appendChild $elem]

	## message elem
	set elem           [$doc createElement "message"]
	set message_node   [$respAuth appendChild $elem]
	set message_tnode  [$doc createTextNode $message_text]
	$message_node appendChild $message_tnode

	return $resp
}

#
# Freebets server proc.
# Actions that have previously failed to be checked (for whatever reason)
#
# xml_msg - raw xml post

proc OB_freebets::recheck_failed_actions args {

	if { [catch {
		set rs [tb_db::tb_exec_qry fb_get_failed_check_actions]
	} msg] } {
		log 1 "Failed to get failed freebets check actions: $msg"
		return 0
	}

	set num_actions   [db_get_nrows $rs]
	set num_succeeded 0
	set num_failed    0

	for { set i 0 } { $i < $num_actions } { incr i } {
		tb_db::tb_begin_tran

		set id             [db_get_col $rs $i id]
		set action         [db_get_col $rs $i action]
		set user_id        [db_get_col $rs $i cust_id]
		set aff_id         [db_get_col $rs $i aff_id]
		set value          [db_get_col $rs $i value]
		set evocs          [db_get_col $rs $i evocs]
		set sort           [db_get_col $rs $i sort]
		set vch_type       [db_get_col $rs $i vch_type]
		set vch_trigger_id [db_get_col $rs $i vch_trigger_id]
		set ref_id         [db_get_col $rs $i ref_id]
		set ref_type       [db_get_col $rs $i ref_type]
		set cr_date        [db_get_col $rs $i cr_date]
		set source         [db_get_col $rs $i source]
		set promo_code     [db_get_col $rs $i promo_code]

		log 10 "attempting to recheck $id,\
								  $action,\
								  $user_id,\
								  $aff_id,\
								  $value,\
								  $evocs,\
								  $sort,\
								  $vch_type,\
								  $vch_trigger_id,\
								  $ref_id,\
								  $ref_type,\
								  $cr_date,\
								  $source,\
								  $promo_code"

		if { ![check_action_local $action \
								  $user_id \
								  $aff_id \
								  $value \
								  $evocs \
								  $sort \
								  $vch_type \
								  $vch_trigger_id \
								  $ref_id \
								  $ref_type \
								  $cr_date \
								  $source \
								  $promo_code] } {

			log 1 "Rechecking failed."
			set ok 0

		} elseif { [catch {
			tb_db::tb_exec_qry fb_remove_failed_check_action $id
		} msg] } {
			log 1 "Failed to get failed freebets check actions: $msg"
			set ok 0
		} else {
			set ok 1
		}

		if { $ok } {
			incr num_succeeded
			tb_db::tb_commit_tran
		} else {
			incr num_failed
			tb_db::tb_rollback_tran
		}

	}

	log 1 "Rechecked $num_actions:\
			$num_succeeded succeeded; $num_failed failed."

	tb_db::tb_close $rs

}

#
# Freebets server proc
#
# Parses a freebets server check_action document.
#
# xml_msg - raw xml post

proc OB_freebets::parse_check_action_xml {xml_msg} {

	log 10 "in parse_check_action_xml"

	set check_action_nodes [$xml_msg selectNode "check_action"]
	set check_action [list]

	foreach check_action_node $check_action_nodes {

		# REQUIRED nodes
		foreach required {user_id value bet_id bet_type} {
			if {[catch {
				set node [$check_action_node selectNode "${required}/text()"]
				set $required [$node nodeValue]
			} msg]} {
				error "required node not present: $required"
			}
		}
		
		# Will Hill compatibility
		set ref_id   $bet_id
		set ref_type $bet_type

		# OPTIONAL nodes
		set aff_id			""
		set evocs			""
		set sort			""
		set vch_type		""
		set vch_trigger_id	""
		set source			"I"
		set promo_code		""

		foreach optional {aff_id evocs sort vch_type vch_trigger_id source promo_code} {
			catch {
				set node [$check_action_node selectNode "${optional}/text()"]
				set $optional [$node nodeValue]
			}
		}

		# get actions
		set actions_node [$check_action_node selectNode "actions"]
		set action_nodes [$actions_node selectNode "action/text()"]

		foreach action_node $action_nodes {
			lappend action_list [$action_node nodeValue]
		}

		lappend check_action [list $action_list $user_id $aff_id $value $evocs $sort $vch_type $vch_trigger_id $ref_id $ref_type $source $promo_code]

	}

	log 10 "parse_check_action_xml returning: $check_action"

	return $check_action
}

#
# Freebets server proc
#
# Builds a freebets server check_action document.
#
# For param arguments, see check_action_http_req

proc OB_freebets::build_check_action_xml {action user_id aff_id value evocs sort vch_type vch_trigger_id ref_id ref_type source $promo_code} {

	package require tdom

	dom setResultEncoding [OT_CfgGet XML_ENCODING "UTF-8"]

	set doc            [dom createDocument "shared_server"]
	set sharedserver   [$doc documentElement]

	set req            [$doc createElement "request"]
	set message        [$sharedserver appendChild $req]

	set elem           [$doc createElement "reqCheckAction"]
	set reqCheck       [$message appendChild $elem]

	set elem           [$doc createElement "check_action"]
	set check_action   [$reqCheck appendChild $elem]

	## user_id node
	set elem           [$doc createElement "user_id"]
	set user_id_node   [$check_action appendChild $elem]
	set user_id_tnode  [$doc createTextNode $user_id]
	$user_id_node appendChild $user_id_tnode

	## value node
	set elem           [$doc createElement "value"]
	set value_node     [$check_action appendChild $elem]
	set value_tnode    [$doc createTextNode $value]
	$value_node appendChild $value_tnode

	## ref_id node
	set elem           [$doc createElement "ref_id"]
	set ref_id_node    [$check_action appendChild $elem]
	set ref_id_tnode   [$doc createTextNode $ref_id]
	$ref_id_node appendChild $ref_id_tnode

	## ref_type node
	set elem           [$doc createElement "ref_type"]
	set ref_type_node  [$check_action appendChild $elem]
	set ref_type_tnode [$doc createTextNode $ref_type]
	$ref_type_node appendChild $ref_type_tnode

	## aff_id node
	set elem           [$doc createElement "aff_id"]
	set aff_id_node	   [$check_action appendChild $elem]
	set aff_id_tnode   [$doc createTextNode $aff_id]
	$aff_id_node appendChild $aff_id_tnode

	## evocs node
	set elem           [$doc createElement "evocs"]
	set evocs_node     [$check_action appendChild $elem]
	set evocs_tnode    [$doc createTextNode $evocs]
	$evocs_node appendChild $evocs_tnode

	## sort node
	set elem           [$doc createElement "sort"]
	set sort_node      [$check_action appendChild $elem]
	set sort_tnode     [$doc createTextNode $sort]
	$sort_node appendChild $sort_tnode

	## vch_type node
	set elem           [$doc createElement "vch_type"]
	set vch_type_node  [$check_action appendChild $elem]
	set vch_type_tnode [$doc createTextNode $vch_type]
	$vch_type_node appendChild $vch_type_tnode

	## vch_trigger_id node
	set elem                 [$doc createElement "vch_trigger_id"]
	set vch_trigger_id_node  [$check_action appendChild $elem]
	set vch_trigger_id_tnode [$doc createTextNode $vch_trigger_id]
	$vch_trigger_id_node appendChild $vch_trigger_id_tnode

	## source node
	set elem           [$doc createElement "source"]
	set source_node    [$check_action appendChild $elem]
	set source_tnode   [$doc createTextNode $source]
	$source_node appendChild $source_tnode

	## promo_code node
	set elem           		[$doc createElement "promo_code"]
	set promo_code_node		[$check_action appendChild $elem]
	set promo_code_tnode	[$doc createTextNode $promo_code]
	$promo_code_node appendChild $promo_code_tnode

	if {[llength $action] > 0 } {
		set elem [$doc createElement "actions"]
		set actions_node [$check_action appendChild $elem]
	}

	# add overrirdes elements
	for {set i 0} {$i < [llength $action]} {incr i} {
		set elem [$doc createElement "action"]
		set action_node [$actions_node appendChild $elem]
		set action_text_node [$doc createTextNode [lindex $action $i]]
		$action_node appendChild $action_text_node
	}

	set xml_msg [printMessage $req]

	return $reqCheck
}

# clears up node
proc OB_freebets::destroyMessage {node} {

	if {[catch {set doc [$node ownerDocument]}]} {
		set doc $node
	}
	catch {$doc delete}
}

#
proc OB_freebets::printMessage {node} {
	set doc      [$node ownerDocument]
	set doc_elem [$doc documentElement]
	set xml      [$doc_elem asXML]

	return $xml
}



# function to convert from the shifted values stored for cg stuff
proc OB_freebets::convert_from_cg_db {db_val} {

	set length [string length $db_val]

	switch -- $length {
		1 {return "0.0$db_val"}
		2 {return "0.$db_val"}
		default {return "[string range $db_val 0 [expr {$length - 3}]].[string range $db_val [expr {$length - 2}] end]"}
	}

}


# =====================================================
# proc: get_trigger_list
# Figures out which triggers which should be checked
# for the specific offer.
# =====================================================
proc OB_freebets::get_trigger_list {cust_id offer_id} {

	global FB_OFFERS_ARR

	# vars to be used later
	set trig_list {}
	set type_codes {}

	if {[info exists FB_OFFERS_ARR($cust_id,$offer_id,full_list)]} {
		set FB_OFFERS_ARR($cust_id,$offer_id,trigger_ids) $FB_OFFERS_ARR($cust_id,$offer_id,full_list)
	} else {
		set FB_OFFERS_ARR($cust_id,$offer_id,full_list) $FB_OFFERS_ARR($cust_id,$offer_id,trigger_ids)
	}

	foreach trigger_id $FB_OFFERS_ARR($cust_id,$offer_id,trigger_ids) {
		# check how many times this trigger was called - if ever
		if [catch {set rs [tb_db::tb_exec_qry fb_called_triggers $trigger_id $cust_id]} msg] {
			log 1 "ERROR: $msg"
			return
		}

		set ARR($trigger_id,count) [db_get_nrows $rs]

		# get the basic trigger info
		if [catch {set curr_rs [tb_db::tb_exec_qry fb_basic_trigger $trigger_id]} msg] {
			log 1 "ERROR: $msg"
			return
		}

		lappend ARR(triggers)          $trigger_id
		set ARR($trigger_id,rank)      [db_get_col $curr_rs 0 rank]
		set ARR($trigger_id,type_code) [db_get_col $curr_rs 0 type_code]

		# gather a list of type codes
		if {[lsearch $type_codes $ARR($trigger_id,type_code)] == -1} {
			lappend type_codes $ARR($trigger_id,type_code)
		}

		tb_db::tb_close $rs
		tb_db::tb_close $curr_rs
	}


	#set min_count & min_rank to mad values
	set min_count 999999
	set min_rank  999999

	# For each type figure out which
	# trigger needs to be called
	foreach type_code $type_codes {
		set _tmp_list {}

		# get this list of triggers
		# with this type code
		foreach trigger_id $ARR(triggers) {
			if {$ARR($trigger_id,type_code) == $type_code} {
				lappend _tmp_list $trigger_id
			}
		}

		# we now have a list of all the triggers with the same type codes
		# now we need to get th one with the least count and rank
		# this is where we will use our min_count and min_rank from above
		set trigger [list -1]

		foreach trig $_tmp_list {

			if {$ARR($trig,count) < $min_count} {
				set min_count $ARR($trig,count)

				# there can be more than one trigger with the same count
				# so delete them all - arrrr!
				foreach t $trigger {
					set _tmp_list [_remove_from_list $_tmp_list $t]
				}

				# set the trigger list to your triger
				set trigger $trig

			} elseif {$ARR($trig,count) == $min_count} {
				# its the same so append onto current trigger list
				lappend trigger $trig

			} else {
				# This has a higher count so delete from _tmp_list
				set _tmp_list [_remove_from_list $_tmp_list $trig]
			}

		}

		set trigger [list -1]
		# Same idea but this time leave in the one with the lowest rank
		foreach trig  $_tmp_list {

			if {$ARR($trig,rank) < $min_rank} {
				foreach t $trigger {
					set _tmp_list [_remove_from_list $_tmp_list $t]
				}

				set min_rank $ARR($trig,rank)
				set trigger $trig

			} elseif {$ARR($trig,rank) == $min_rank} {
				lappend trigger $trig

			} else {
				set _tmp_list [_remove_from_list $_tmp_list $trig]

			}
		}

		# stick it onto the end of the list we are going to return
		foreach i $_tmp_list {
			if {[lsearch $trig_list $i] == -1} {
				lappend trig_list $i

			}
		}
	}

	set FB_OFFERS_ARR($cust_id,$offer_id,trigger_ids) $trig_list
}

proc OB_freebets::_remove_from_list {_list _item} {
	# only works on non repetitive lists
	# get the index


	set _index [lsearch $_list $_item]
	if {$_index == -1} {
		return $_list
	} else {

		# construct two lists, one before index one after
		set _list1 [lrange $_list 0 [expr {$_index - 1}]]
		set _list2 [lrange $_list [expr {$_index + 1}] [llength $_list]]

		# join & return
		return [concat $_list1 $_list2]
	}
}


# initialise freebets when file is sourced.
OB_freebets::init_freebets
