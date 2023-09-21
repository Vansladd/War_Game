# $Id: freebets.tcl,v 1.1 2011/10/04 12:26:11 xbourgui Exp $
# Copyright (c) 2008 Orbis Technology Ltd. All rights reserved.
# Faster, shinier (but somewhat limited) version of Freebets.
#
# The intent is to eventually replace the old freebet code with this new one, more modular and faster
#
# Procedures:
#   ob_fbets::init
#   ob_fbets::check_action_fast
#

package provide fbets_fbets 4.5

namespace eval ob_fbets {

	variable INIT
	variable CFG
	variable OFFER
}



# Dependencies
package require util_log
package require util_db
package require util_gc



# initialise
#
proc ob_fbets::init {} {

	variable INIT
	variable CFG

	if {[info exists INIT] && $INIT == "1"} {
		return
	}

	set CFG(offer_cache_time_secs) 300
	_prepare_queries 
	_prepare_check_queries
	_prepare_cache_queries
	_prepare_fulfill_queries

	set INIT 1
}

proc ob_fbets::_prepare_queries {} {

	ob_db::store_qry ob_fbets::find_offer_triggers_for_offer {

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
	} 300

	ob_db::store_qry ob_fbets::check_for_first_action {

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
	} 300

	#
	# Check if any game from a game group has been played before
	# If one row is returned and it has a num_plays of 1, that means that the current
	# game is the only game from the group that has been played.  If 2 rows, then
	# (at least) two rows exist in tCGGameLastPlay, so the group has been played at
	# least twice. If no rows are returned then something is wrong.
	ob_db::store_qry ob_fbets::gp_has_game_group_been_played_before {
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
	} 300

	# Check if any rows exist in tUGDrawAccount for that customer, for that draw group.
	# If there are no rows, then the customer has not played this group of game before.
	ob_db::store_qry ob_fbets::gp_sng_has_game_group_been_played_before {
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
	} 300

}



