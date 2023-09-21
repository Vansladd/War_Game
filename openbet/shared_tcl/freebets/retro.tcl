# $Id: retro.tcl,v 1.1 2011/10/04 12:26:11 xbourgui Exp $
# (C)2005 Orbis Technology Ltd. All rights reserved.
#
# Deal with retrospective freebets, specifically with the task of issuing a
# retrospective freebets.
#
# This table details trigger types, those marker with and asterisk are
# not supported in retro.
#
#   BET          Action which will fire off on all bets to check for any
#                triggers related to the current bet
#   FBET         Customers first bet after registration (aka BET1)
#   DEP          Any deposit
#   DEP1         First Deposit
#   REG          Normal registration
#   XGAMEBET     Any External Game bet
#   XGAMEBET1    First External Game Bet
#   SPORTSBET    A bet on the sportsbook
#   SPORTSBET1   First bet on the sportsbook
#   VOUCHER      Voucher
#   REFERRAL*    Customer refers potential new registrations
#   REFEREE*     Customer registers having been referred
#   INTRO*       Offer freebets based on a customer learned about us
#   PROMO*       Offer freebets based on promotional codes
#   BUYMGETN*    Buy M FOG or SNG games and get N free
#   FIRSTGAME    First Game From FOG Group
#   CUSTGROUP    Customer is a member of a group
#   CUMBETSTK    Customer stakes a minimum amount
#   CUMBETTUR    Customer turnsover a minimum amount
#   CUMBETLOS    Customer looses a minimum amount
#
# Warning:
#   This does not supports 'manual adjusment' style offers. You should use
#   consider cash tokens instead.
#
# Configuration:
#    none
#
# Synopsis:
#   package require freebets_retro ?4.5?
#
# Procedures:
#   ob_freebets_retro::init  - initialise
#   ob_freebets_retro::issue - issue a retrospective freebet offer
#
package provide freebets_retro 4.5



# Dependencies - request admin screens db
#
set ::admin_screens 1
package require util_db
package require util_log



# Variables
#
namespace eval ob_freebets_retro {
	variable INIT 0
	variable CFG

	# details of the offer currently being issued
	variable OFFER

	# details of triggers for the currently issuing offer
	variable TRIGGERS

	# details of triggers amounts for currently issusing offer
	variable TRIGGER_AMOUNTS
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------


# Initialise
#
proc ob_freebets_retro::init args {

	variable INIT
	variable CFG

	if {$INIT} {
		return
	}

	ob_log::init
	ob_db::init

	foreach {n d} [list \
		enable_sports 1 \
		enable_fog    0 \
		enable_sng    0 \
		enable_xgame  0 \
	] {
		set CFG($n) [OT_CfgGet [string toupper $n] $d]
	}

	foreach {n v} $args {
		set CFG([string trimleft $n -]) $v
	} 

	_prep_qrys
	_prep_trigger_qrys

	set INIT 1
}



# Prepare queries
#
proc ob_freebets_retro::_prep_qrys {} {


	# select all the retro offers waiting to be fulfilled
	ob_db::store_qry ob_freebets_retro::sel_offers {
		select
			offer_id
		from
			tOffer
		where
			retro        = 'Y'
		-- ready to issue
		and retro_status = 'R'
		and retro_end_date < current
	}


	#-----------------------------------------------------------------------
	# Basic offer information
	#-----------------------------------------------------------------------

	# select details about this offer
	ob_db::store_qry ob_freebets_retro::sel_offer {
		select
			start_date,
			end_date,
			retro,
			retro_status,
			comparison,
			-- used to filter out inelligable customers
			lang,
			channels,
			country_code,
			max_claims
		from
			tOffer
		where
			offer_id   = ?
	}

	# select the triggers for an offer
	ob_db::store_qry ob_freebets_retro::sel_triggers {
		select
			y.sort,
			y.qualification,
			t.trigger_id,
			t.type_code,
			t.rank
		from
			tTriggerType   y,
			tTrigger       t
		where
			y.type_code    = t.type_code
		and t.offer_id     = ?
		order by
			-- get the qualifications tiggers first
			y.qualification desc,
			t.rank
	}

	ob_db::store_qry ob_freebets_retro::sel_trigger_amounts {
		select
			ccy_code,
			amount
		from
			tTriggerAmount
		where
			trigger_id = ?
	}

	#-----------------------------------------------------------------------
	# Temporary Table
	#-----------------------------------------------------------------------

	# stores a list psuedo called triggers
	#
	#   trigger_id        - trigger id
	#   cust_id           - customer id
	#   value             - value customer fulfilled trigger with
	#
	ob_db::store_qry ob_freebets_retro::create_temp_table {
		create temp table tTemp (
			trigger_id int            not null,
			cust_id    int            not null,
			value      decimal(12, 2)
		) with no log
	}

	ob_db::store_qry ob_freebets_retro::create_temp_index_x1 {
		create index cTemp_x1 on tTemp(cust_id)
	}

	# used when we can't do this any other way
	ob_db::store_qry ob_freebets_retro::ins_temp {
		insert into tTemp(trigger_id, cust_id, value) values (?, ?, ?)
	}

	# delete inelligable customer from the temp table
	ob_db::store_qry ob_freebets_retro::del_temp {
		delete from tTemp
		where
			cust_id in (
				select
					c.cust_id
				from
					tCustomer  c,
					tOffer     o
				where
					o.offer_id = ?
				and (
					o.lang is not null and c.lang <> o.lang
					or
					o.channels is not null and o.channels not like '%'||c.source||'%'
					or
					o.country_code is not null and c.country_code <>
						o.country_code
					or
					c.status = 'S'
				)
			)
	}

	# select all the elligable customer from the temp table for inserting
	# triggers
	ob_db::store_qry ob_freebets_retro::sel_temp {
		select
			trigger_id,
			cust_id,
			value
		from
			tTemp
	}

	# drop that baby
	ob_db::store_qry ob_freebets_retro::drop_temp_table {
		drop table tTemp
	}



	#-----------------------------------------------------------------------
	# Called triggers
	#-----------------------------------------------------------------------

	# Select all the called triggers
	ob_db::store_qry ob_freebets_retro::sel_called_triggers {
		select
			ct.trigger_id,
			ct.cust_id
		from
			tTrigger       t,
			tCalledTrigger ct
		where
			t.offer_id     = ?
		and t.trigger_id   = ct.trigger_id
		and ct.status      = 'A'
		order by
			cust_id
	}

	# these queries update offers and customers
	ob_db::store_qry ob_freebets_retro::ins_called_trigger {
		execute procedure pInsCalledTrigger(
			p_offer_id     = ?,
			p_trigger_id   = ?,
			p_cust_id      = ?,
			p_called_date  = CURRENT,
			p_value        = ?
		)
	}


	#-----------------------------------------------------------------------
	# Claiming an offer
	#-----------------------------------------------------------------------

	# insert claimed offer
	ob_db::store_qry ob_freebets_retro::ins_claimed_offer {
		execute procedure pInsClaimedOffer (
			p_offer_id   = ?,
			p_cust_id    = ?,
			p_claim_date = CURRENT
		)
	}

	# claim called triggers
	ob_db::store_qry ob_freebets_retro::claim_called_triggers {
		execute procedure pClmCalledTriggers (
			p_offer_id = ?,
			p_cust_id  = ?
		)
	}

	# create customer tokens
	ob_db::store_qry ob_freebets_retro::create_cust_tokens {
		execute procedure pCreateCustTokens (
			p_claimed_offer = ?,
			p_cust_id 		= ?
		)
	}


	#-----------------------------------------------------------------------
	# Updating offers
	#-----------------------------------------------------------------------

	# update an offer
	ob_db::store_qry ob_freebets_retro::upd_offer {
		execute procedure pUpdOffer(
			p_offer_id         = ?,
			p_retro_status     = ?,
			p_retro_start_date = ?,
			p_retro_end_date   = ?
		)
	}
}



# Prepares queries to do with calcualating if customers had fulfilled triggers.
#
proc ob_freebets_retro::_prep_trigger_qrys {} {

	#
	# this allow you to filter your query by an affiliate, this should be
	# the last part of a query and formatted with the table alias
	#
	# in the query plan, this seems to get applied as a filter of the
	# bet table
	#
	set affiliate_format {
		(
			(t.aff_level = 'Single' and %s.aff_id = t.aff_id)
			or
			(t.aff_level = 'Group'  and %s.aff_id  in (
				select af.aff_id from tAffiliate af
				where af.aff_grp_id = t.aff_grp_id)
			)
			or
			(t.aff_level = 'All'    and %s.aff_id is not null)
			or
			(t.aff_level = 'None'   and %s.aff_id is null)
			or
			t.aff_level is null
		)
	}



	# REG
	ob_db::store_qry ob_freebets_retro::ins_REG [subst {
		insert into tTemp(trigger_id, cust_id)
		select
			t.trigger_id,
			c.cust_id
		from
			tCustomer      c,
			tAcct          a,
			-- take advantage of the fact that pInsTrigger does not care
			-- that amounts are irrelevant to REG
			tTrigger       t,
			tTriggerAmount ta
		where
			c.status       = 'A'
		and c.cr_date      between ? and ?
		and c.cust_id      = a.cust_id
		and a.status       = 'A'
		and ta.ccy_code    = a.ccy_code
		and t.trigger_id   = ?
		and t.trigger_id   = ta.trigger_id
		and [format $affiliate_format c c c c]
	}]


	# DEP/DEP1
	set sql {
		insert into tTemp(trigger_id, cust_id, value)
		select
			t.trigger_id,
			a.cust_id,
			p.amount
		from
			tAcct          a,
			tPmt           p,
			tTrigger       t,
			tTriggerAmount ta
		where
			a.status       = 'A'
		and a.acct_id      = p.acct_id
		and p.cr_date      between ? and ?
		and p.payment_sort = 'D'
		and p.status       = 'Y'
		and p.amount       >= ta.amount
		and ta.ccy_code    = a.ccy_code
		and t.trigger_id   = ?
		and t.trigger_id   = ta.trigger_id
		%s
	}

	ob_db::store_qry ob_freebets_retro::ins_DEP [format $sql {}]
	ob_db::store_qry ob_freebets_retro::ins_DEP1 [format $sql {
		and p.rowid = (
			select min(fp.rowid) from tPmt fp
				where fp.acct_id = p.acct_id
		)
	}]


	# SPORTSBET/SPORTSBET1
	set sql [subst {
		insert into tTemp(trigger_id, cust_id, value)
		select
			t.trigger_id,
			a.cust_id,
			b.stake
		from
			tAcct          a,
			tBet           b,
			tTrigger       t,
			tTriggerAmount ta
		where
			a.status       = 'A'
		and a.acct_id      = b.acct_id
		and b.status       = 'A'
		and b.cr_date      between ? and ?
		and b.stake        >= ta.amount
		and ta.ccy_code    = a.ccy_code
		and t.trigger_id   = ?
		and t.trigger_id   = ta.trigger_id
		and [format $affiliate_format b b b b]
		%s
	}]

	ob_db::store_qry ob_freebets_retro::ins_SPORTSBET [format $sql {}]
	ob_db::store_qry ob_freebets_retro::ins_SPORTSBET1 [format $sql {
		and b.rowid = (
			select min(fb.rowid) from tBet fb where fb.acct_id = a.acct_id
		)
	}]


	# XGAMEBET
	set sql [subst {
		insert into tTemp(trigger_id, cust_id, value)
		select
			t.trigger_id,
			a.cust_id,
			b.stake
		from
			tAcct          a,
			tXGameSub      s,
			tXGameBet      b,
			tTrigger       t,
			tTriggerAmount ta
		where
			a.status       = 'A'
		and s.acct_id      = a.acct_id
		and b.xgame_sub_id = s.xgame_sub_id
		and b.status       = 'A'
		and b.cr_date      between ? and ?
		and b.stake        >= ta.amount
		and ta.ccy_code    = a.ccy_code
		and t.trigger_id   = ?
		and t.trigger_id   = ta.trigger_id
		and [format $affiliate_format s s s s]
		%s
	}]

	ob_db::store_qry ob_freebets_retro::ins_XGAMEBET [format $sql {}]
	ob_db::store_qry ob_freebets_retro::ins_XGAMEBET1 [format $sql {
		and s.rowid = (
			select min(fs.rowid) from tXGameSub fs where fs.acct_id = a.acct_id
		)
	}]


	# BET/FBET
	set sql [subst {
		insert into tTemp(trigger_id, cust_id, value)
		select
			t.trigger_id,
			a.cust_id,
			b.stake
		from
			tAcct          a,
			tTrigger       t,
			tTriggerAmount ta,
			tBet           b
		where
			a.status       = 'A'
		and b.cr_date      between ? and ?
		and b.acct_id      = a.acct_id
		and t.trigger_id   = ?
		and t.trigger_id   = ta.trigger_id
		and ta.ccy_code    = a.ccy_code
		and b.status       = 'A'
		and b.stake        >= ta.amount
		and exists (
			select
				1
			from
				tOBet          ob,
				tEvOc          o,
				tEv            e,
				tTriggerLevel  l
			where
				b.bet_id       = ob.bet_id
			and ob.ev_oc_id    = o.ev_oc_id
			and o.ev_id        = e.ev_id
			and t.trigger_id   = l.trigger_id
			and (
				l.level  = 'CLASS'     and l.id = e.ev_class_id
				or
				l.level  = 'TYPE'      and l.id = e.ev_type_id
				or
				l.level  = 'EVENT'     and l.id = e.ev_id
				or
				l.level  = 'MARKET'    and l.id = o.ev_mkt_id
				or
				l.level  = 'SELECTION' and l.id = o.ev_oc_id
			)
		)
		and [format $affiliate_format b b b b]
		%s
	}]

	ob_db::store_qry ob_freebets_retro::ins_BET [format $sql {}]
	ob_db::store_qry ob_freebets_retro::ins_FBET [format $sql {
		and b.rowid = (select min(fb.rowid) from tBet fb
			where fb.acct_id = a.acct_id)
	}]


	# CUMBETSTK/CUMBETTUR/CUMBETLOS
	ob_db::store_qry ob_freebets_retro::sel_CUMBET_SPORTS [subst {
		select
			a.cust_id,
			a.ccy_code,
			nvl(sum(b.stake - b.token_value), 0) as stake,
			nvl(sum(b.stake - b.token_value - b.refund), 0) as turnover,
			nvl(sum(b.stake - b.token_value - b.refund - b.winnings), 0)
				as losses
		from
			tAcct          a,
			tTrigger       t,
			tTriggerAmount ta,
			tBet           b
		where
			a.status       = 'A'
		and b.status       = 'A'
		and b.settled_at   between ? and ?
		and b.acct_id      = a.acct_id
		and t.trigger_id   = ta.trigger_id
		and ta.ccy_code    = a.ccy_code
		and t.trigger_id   = ?
		and exists (
			select
				1
			from
				tOBet         ob,
				tEvOc         o,
				tEv           e,
				tTriggerLevel l
			where
				b.status       = 'A'
			and b.bet_id       = ob.bet_id
			and ob.ev_oc_id    = o.ev_oc_id
			and o.ev_id        = e.ev_id
			and t.trigger_id   = l.trigger_id
			and (
				l.level  = 'CLASS'     and l.id = e.ev_class_id
				or
				l.level  = 'TYPE'      and l.id = e.ev_type_id
				or
				l.level  = 'EVENT'     and l.id = e.ev_id
				or
				l.level  = 'MARKET'    and l.id = o.ev_mkt_id
				or
				l.level  = 'SELECTION' and l.id = o.ev_oc_id
			)
		)
		and [format $affiliate_format b b b b]
		group by
			1, 2
	}]

	ob_db::store_qry ob_freebets_retro::sel_CUMBET_XGAME [subst {
		select
			a.cust_id,
			a.ccy_code,
			nvl(sum(b.stake - b.token_value), 0) as stake,
			nvl(sum(b.stake - b.token_value - b.refund), 0) as turnover,
			nvl(sum(b.stake - b.token_value - b.refund - b.winnings), 0)
				as losses
		from
			tAcct          a,
			tXGameSub      s,
			tXGameBet      b,
			tTrigger       t,
			tTriggerAmount ta
		where
			a.status       = 'A'
		and b.status       = 'A'
		and b.settled_at   between ? and ?
		and s.acct_id      = a.acct_id
		and b.settled      = 'Y'
		and b.xgame_sub_id = s.xgame_sub_id
		and t.trigger_id   = ?
		and t.trigger_id   = ta.trigger_id
		and ta.ccy_code    = a.ccy_code
		and exists (
			select
				1
			from
				tTriggerLevel l
			where
				l.trigger_id = t.trigger_id
			and (
				 l.level = 'XGAME'       and l.id = b.xgame_id
			)
		)
		group by
			1, 2
	}]


	# this is a format for gp games to simply the game selection
	set gp_format {
		-- this looks far more messy than it actually is,
		-- all it in fact does is select the FOG/SNG games which this
		-- may have the id
		l.level  = 'GPGAME'      and %s = (
			select gpg.%s from tGPGame gpg
			where
				gpg.system_arch = '%s'
			and gpg.gp_game_id = l.id
		)
		or
		l.level  = 'GPGAMEGRP'      and %s = (
			select gpg.%s from tGPGame gpg, tGPGameGrpLk gpl
			where
				gpg.system_arch    = '%s'
			and gpg.gp_game_id     = gpl.gp_game_id
			and gpl.gp_game_grp_id = l.id
		)
	}


	# taken from affiliate manager
	ob_db::store_qry ob_freebets_retro::sel_CUMBET_FOG [subst {
		select
			a.cust_id,
			a.ccy_code,
			nvl(sum(s.stakes), 0)              as stake,
			nvl(sum(s.stakes), 0)              as turnover,
			nvl(sum(s.stakes - s.winnings), 0) as losses
		from
			tAcct          a,
			tCGAcct        ca,
			tCGGSFinished  f,
			tCGGameSummary s,
			tTrigger       t,
			tTriggerAmount ta
		where
			a.status       = 'A'
		and a.acct_id      = ca.acct_id
		and ca.cg_acct_id  = s.cg_acct_id
		and s.cg_game_id   = f.cg_game_id
		and f.finished     between ? and ?
		and t.trigger_id   = ?
		and t.trigger_id   = ta.trigger_id
		and ta.ccy_code    = a.ccy_code
		and exists (
			select
				1
			from
				tTriggerLevel l
			where
				t.trigger_id   = l.trigger_id
			and (
				l.level  = 'FOGGAME'     and l.id = s.cg_id
				or
				[format $gp_format \
					s.cg_id cg_id FOG \
					s.cg_id cg_id FOG]
			)
		)
		and [format $affiliate_format s s s s]
		group by
			1, 2
	}]

	# taken from affiliate manager
	ob_db::store_qry ob_freebets_retro::sel_CUMBET_SNG [subst {
		select
			a.cust_id,
			a.ccy_code,
			nvl(sum(s.total_stake), 0) as stake,
			nvl(sum(s.total_stake - s.refund), 0) as turnover,
			nvl(sum(s.total_stake - s.winnings - s.refund), 0)
				as losses
		from
			tUGGameType    gt,
			tUGDrawDef     f,
			tUGGameSummary s,
			tAcct          a,
			tTrigger       t,
			tTriggerAmount ta
		where
			a.status        = 'A'
		-- paranoid: do we need to check on this _and_ the finished date
		and s.status        = 'C'
		-- requires index
		and s.finished      between ? and ?
		and s.acct_id       = a.acct_id
		and gt.ug_type_code = f.ug_type_code
		and f.ug_type_code  = s.ug_type_code
		and f.version       = s.version
		and t.trigger_id    = ?
		and t.trigger_id    = ta.trigger_id
		and ta.ccy_code     = a.ccy_code
		and exists (
			select
				1
			from
				tTriggerLevel l
			where
				t.trigger_id   = l.trigger_id
			and (
				-- you cannot do this based on SNG level, since this is
				-- expressed as a string not an nice integer
				[format $gp_format \
					gt.ug_type_grp_code ug_type_grp_code SNG \
					gt.ug_type_grp_code ug_type_grp_code SNG]
			)
		)
		and [format $affiliate_format s s s s]
		group by
			1, 2
	}]
}



#--------------------------------------------------------------------------
# Procedures
#--------------------------------------------------------------------------

# Checks a list of customers against all triggers for an offer
# creating tokens/payments for all those that match triggers
#
# We assume that customers provided haven't claimed this offer yet.
#
#   offer_id - offer id, or all for all outstanding
#
proc ob_freebets_retro::issue {{offer_id all}} {

	if {$offer_id == "all"} {
		ob_db::foreachrow -force ob_freebets_retro::sel_offers {
			_issue $offer_id
		}
	} else {
		_issue $offer_id
	}
}



# Actual issuer. This tries to be verbose with error messages, if a check is
# simple to do and has a low overhead, then it is done here. this is private.
#
#   offer_id - offer id
#
proc ob_freebets_retro::_issue {offer_id} {

	variable CFG
	variable OFFER
	variable TRIGGERS
	variable TRIGGER_AMOUNTS

	_clean_up


	# get the offer
	set rs [ob_db::exec_qry ob_freebets_retro::sel_offer $offer_id]

	set OFFER(offer_id)     $offer_id
	set OFFER(start_date)   [db_get_col $rs 0 start_date]
	set OFFER(end_date)     [db_get_col $rs 0 end_date]
	set OFFER(retro)        [db_get_col $rs 0 retro]
	set OFFER(retro_status) [db_get_col $rs 0 retro_status]
	set OFFER(comparison)   [db_get_col $rs 0 comparison]
	# lang, chanel and country are used to filter out customers who are
	# inelligable to claim the offer
	set OFFER(lang)         [db_get_col $rs 0 lang]
	set OFFER(channels)   [db_get_col $rs 0 channels]
	set OFFER(country_code) [db_get_col $rs 0 country_code]
	set OFFER(max_claims)   [db_get_col $rs 0 max_claims]

	ob_db::rs_close $rs

	if {$OFFER(retro) != "Y"} {
		error "This offer is not a retrospective offer"
	}

	if {[lsearch {P R} $OFFER(retro_status)] == -1} {
		error "This retro offer neither pending, nor ready to issue"
	}


	ob_log::write INFO {ob_freebets_retro: Issuing offer $offer_id}
	ob_log::write_array DEBUG OFFER



	# get both the triggers and check that the triggers are set up correctly
	set TRIGGERS(trigger_ids) [list]

	ob_db::foreachrow ob_freebets_retro::sel_triggers $offer_id {
		if {$sort == "N"} {
			# paranoia: stored procedures should prevents this
			error "May not have a normal trigger for a retro offer"
		}
		lappend TRIGGERS(trigger_ids) $trigger_id
		set TRIGGERS($trigger_id,type_code)    $type_code

		ob_db::foreachrow ob_freebets_retro::sel_trigger_amounts $trigger_id {
			set TRIGGER_AMOUNTS($trigger_id,$ccy_code,amount) $amount
		}
	}

	ob_log::write INFO \
		{ob_freebets_retro: Offer has [llength $TRIGGERS(trigger_ids)] triggers}
	ob_log::write_array DEBUG TRIGGERS
	ob_log::write_array DEBUG TRIGGER_AMOUNTS



	# set the offer status to issuing, which really starts here
	set OFFER(retro_start_date) [clock format [clock scan now] \
		-format {%Y-%m-%d %H:%M:%S}]
	ob_db::rs_close [ob_db::exec_qry ob_freebets_retro::upd_offer $offer_id I \
		$OFFER(retro_start_date) ""]



	foreach trigger_id $TRIGGERS(trigger_ids) {
		set type_code $TRIGGERS($trigger_id,type_code)

		ob_log::write INFO \
			{ob_freebets_retro: Attempting to fulfill $type_code trigger \
			$trigger_id}


		# standard insert queries
		switch $type_code {
			REG -
			DEP -
			DEP1 -
			BET -
			FBET -
			SPORTSBET -
			SPORTSBET1 -
			XGAMEBET -
			XGAMEBET1 {
				set qry "ob_freebets_retro::ins_$type_code"

				ob_db::exec_qry $qry $OFFER(start_date) $OFFER(end_date)\
					$trigger_id

				set nrows [ob_db::garc $qry]

				ob_log::write INFO {ob_freebets_retro: Inserted $nrows rows}
			}
			CUMBETSTK -
			CUMBETTUR -
			CUMBETLOS {
				_ins_temp_CUMBET $type_code $OFFER(start_date) \
					$OFFER(end_date) $trigger_id
			}
			CUSTGROUP {
				# do nothing
			}
			default {
				error "Trigger $trigger_id type $type_code not supported"
			}
		}

		unset trigger_id ;# must unset
	}


	# remove bad customers, wrong currency, wrong language, wrong channel
	ob_db::exec_qry ob_freebets_retro::del_temp $offer_id

	set nrows [ob_db::garc ob_freebets_retro::del_temp]

	ob_log::write INFO \
		{ob_freebets_retro: Deleted $nrows inelligable customers}


	# insert triggers for customers
	ob_db::foreachrow -fetch -nrowsvar nrows ob_freebets_retro::sel_temp {

		ob_log::write DEBUG \
			{ob_freebets_retro: Inserting called trigger $trigger_id for \
			customer $cust_id with value $value}

		if {[catch {
			ob_db::exec_qry ob_freebets_retro::ins_called_trigger $offer_id \
				$trigger_id $cust_id $value
		} msg]} {
			ob_log::write ERROR \
				{ob_freebets_retro: Failed to insert called trigger: $msg}
		}
	}

	ob_log::write INFO {ob_freebets_retro: Attempted to insert $nrows triggers}


	# this following code is a bit odd looking, so let me explain
	#
	# since we are using a query grouped by customer, we'll get a series
	# of rows for each one. once we know we've got all the information about
	# that customer, we can then go on to determine if they have fulfilled
	# enough triggers to qualify for the offer.
	# Note: a customer can qualify more than once

	set CUST(cust_id) ""
	set num_claims 0 ;# just for logging
	ob_db::foreachrow ob_freebets_retro::sel_called_triggers $offer_id {

		if {$CUST(cust_id) != "" && $cust_id != $CUST(cust_id)} {
			_make_claims CUST
			incr num_claims $CUST(num_claims)
		}

		ob_log::write DEV \
			{ob_freebets_retro: Found called trigger $trigger_id for customer \
			$cust_id}

		if {$cust_id != $CUST(cust_id)} {
			array unset CUST
			set CUST(cust_id) $cust_id
		}

		if {![info exists CUST($trigger_id,fulfilled)]} {
			set CUST($trigger_id,fulfilled) 0
		}

		incr CUST($trigger_id,fulfilled)
	}

	# there will be a last one, since it won't change on the last repitition
	# of the loop
	if {$CUST(cust_id) != ""} {
		_make_claims CUST
		incr num_claims $CUST(num_claims)
	}


	ob_log::write INFO {ob_freebets_retro: $num_claims claims}


	set OFFER(retro_end_date) [clock format [clock scan now] \
		-format {%Y-%m-%d %H:%M:%S}]
	ob_db::rs_close [ob_db::exec_qry ob_freebets_retro::upd_offer $offer_id C \
		$OFFER(retro_start_date) $OFFER(retro_end_date)]


	ob_log::write INFO {ob_freebets_retro: Complete}


	_clean_up
}



# Attempt to claim the offer for the customer listed. Private.
#
#   CUSTARR - the name of an array in the calling scope which contains details
#             of which triggers the customer has fulfilled
#
#             CUST(cust_id) - customer id
#             CUST(*,fulfilled) - number of times that trigger was fulfilled
#
proc ob_freebets_retro::_make_claims {CUSTARR} {

	variable OFFER
	variable TRIGGERS

	upvar 1 $CUSTARR CUST

	set CUST(num_claims) 0

	while {[set num_fulfilled [llength [array names CUST *,fulfilled]]] > 0} {

		ob_log::write DEBUG \
			{ob_freebets_retro: Customer $CUST(cust_id) fulfilled \
			$num_fulfilled triggers}

		ob_log::write_array DEV CUST

		# remove up to one of each trigger
		foreach trigger_id $TRIGGERS(trigger_ids) {
			if {[info exists CUST($trigger_id,fulfilled)]} {
				incr CUST($trigger_id,fulfilled) -1
				if {$CUST($trigger_id,fulfilled) == 0} {
					unset CUST($trigger_id,fulfilled)
				}
			}
		}

		if {
			$OFFER(comparison) == "O" && $num_fulfilled > 0
			||
			$OFFER(comparison) == "A" && $num_fulfilled >=
				[llength $TRIGGERS(trigger_ids)]
		} {
			# make sure that we don't claim too many times
			if {
				$OFFER(max_claims) == "" || $CUST(num_claims) <
					$OFFER(max_claims)
			} {
				if {[catch {
					_claim_offer $OFFER(offer_id) $CUST(cust_id)
				} msg]} {
					ob_log::write ERROR \
						{ob_freebets_retro: Failed to claim offer: $msg}
				} else {
					incr CUST(num_claims)
				}
			} else {
				ob_log::write DEBUG \
					{ob_freebets_retro: Customer $CUST(cust_id) reached max \
					number of claims}
				break
			}
		}
	}
}



# Cumulative bets are treated slightly differently, since there is only one
# called trigger per bet, and because there are multiple betting systems
# in operation, we must use a more complex method. Private.
#
#   type_code  - the type of trigger
#   start_date - offer start date
#   end_date   - offer end date
#   trigger_id - trigger id
#
proc ob_freebets_retro::_ins_temp_CUMBET {type_code start_date end_date
	trigger_id} {
	
	variable CFG

	variable TRIGGER_AMOUNTS

	set CUSTS(cust_ids) [list]
	foreach product {SPORTS XGAME FOG SNG} {

		if {!$CFG([string tolower enable_$product])} {
			continue
		}

		ob_log::write DEBUG {ob_freebets_retro: Selecting $product}

		set qry "ob_freebets_retro::sel_CUMBET_$product"

		ob_db::foreachrow -fetch -nrowsvar nrows $qry $start_date $end_date \
			$trigger_id {

			if {![info exists CUSTS($cust_id,ccy_code)]} {
				lappend CUSTS(cust_ids) $cust_id
				set CUSTS($cust_id,ccy_code) $ccy_code
				set CUSTS($cust_id,value) 0.0
			}

			switch $type_code {
				CUMBETSTK {
					set value $stake
				}
				CUMBETTUR {
					set value $turnover
				}
				CUMBETLOS {
					set value $losses
				}
				default {
					error "Unknown type code"
				}
			}

			set CUSTS($cust_id,value) [expr {$CUSTS($cust_id,value) + $value}]
		}

		ob_log::write INFO {ob_freebets_retro: $nrows rows}
	}

	set num_fulfilled 0
	foreach cust_id $CUSTS(cust_ids) {
		set ccy_code $CUSTS($cust_id,ccy_code)
		set value    $CUSTS($cust_id,value)

		if {$value >= $TRIGGER_AMOUNTS($trigger_id,$ccy_code,amount)} {
			ob_log::write DEBUG \
				{ob_freebets_retro: Inserting temp for customer $cust_id, \
				value $value}
			if {[catch {
				ob_db::exec_qry ob_freebets_retro::ins_temp $trigger_id \
					$cust_id $value
			} msg]} {
				ob_log::write WARNING \
					{ob_freebets_retro: Failed to insert temp: $msg}
			}
			incr num_fulfilled
		}
	}

	ob_log::write INFO \
		{ob_freebets_retro: $num_fulfilled customers fulfilled trigger \
		$trigger_id}
}



# Clean up variables and temporary table both prior to use, or after use.
# Private.
#
proc ob_freebets_retro::_clean_up {} {

	variable OFFER
	variable TRIGGERS
	variable TRIGGER_AMOUNTS

	array unset OFFER
	array unset TRIGGERS
	array unset TRIGGER_AMOUNTS

	if {[catch {
		ob_db::exec_qry ob_freebets_retro::drop_temp_table
	} msg] && ![string match "*(-206,-111)*" $msg]} {
		# if it isn't a minor error (table not found) - rethrow
		error $msg $::errorInfo $::errorCode
	}

	ob_db::exec_qry ob_freebets_retro::create_temp_table
	ob_db::exec_qry ob_freebets_retro::create_temp_index_x1
}



# Claim the offer for the customer. This calls a bunch of stored procedures.
#  Private.
#
# This should be wrapped in a catch with a transaction.
#
#   offer_id - offer id
#   cust_id  - customer id
#   throws   - error if failed to claim offer
#
proc ob_freebets_retro::_claim_offer {offer_id cust_id} {

	ob_log::write INFO {ob_freebets_retro: Claiming for customer $cust_id}

	ob_db::begin_tran
	if {[catch {
		# included for backwards compatability
		ob_db::rs_close [ob_db::exec_qry ob_freebets_retro::create_cust_tokens \
			$offer_id $cust_id]

		ob_db::rs_close [ob_db::exec_qry ob_freebets_retro::ins_claimed_offer \
			$offer_id $cust_id]

		ob_db::rs_close [ob_db::exec_qry \
			ob_freebets_retro::claim_called_triggers \
			$offer_id $cust_id]
	} msg]} {
		ob_db::rollback_tran
		error $msg $::errorInfo $::errorCode
	} else {
		ob_db::commit_tran
	}
}
