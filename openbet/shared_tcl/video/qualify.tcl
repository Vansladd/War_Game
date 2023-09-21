# $Id: qualify.tcl,v 1.1 2011/10/04 12:25:13 xbourgui Exp $
# (C) 2008 Orbis Technology Ltd. All rights reserved.
#
# Handles streaming qualification using W&B streaming qualification groups.
# Original implemetation from SkyBet.
#
# Synopsis:
#     package require video_qualify ?4.5?
#
# Procedures:
#	ob_video_qualify::init
#   ob_video_qualify::check_and_update_qual
#   ob_video_qualify::can_view
#
#

package provide video_qualify 4.5

namespace eval ob_video_qualify {

	variable INIT
	set INIT 0
}


# One time init
#
proc ob_video_qualify::init {} {

	variable INIT

	if {$INIT == 1} {
		return
	}

	_prepare_queries

	set INIT 1
}


#
# Qualification logic done on bet placement.
# Checks customers bets against streaming qualification groups.
# cust_id -
# bet_id  - provided by bet package
#
proc ob_video_qualify::check_and_update_qual {cust_id bet_id} {

	# we'll need the acct_id & exch_rate to work out how much the cust has bet in gbp
	#
	foreach {acct_id ccy_code exch_rate} [_get_acct_info $cust_id] {}

	# did this bet involve any events, types or classes that were part of a bet&watch group?
	#
	foreach {ev_ids type_ids class_ids} [_get_bet_dd_info $bet_id] {}
	ob_log::write INFO {for bet_id: $bet_id ev_ids=$ev_ids type_ids=$type_ids class_ids=$class_ids}

	# now find all the bet&watch groups that involve the ids above
	#
	# We are not using this code at the moment since it relates to subscription events
	# array set GROUPS [_get_subscription_qualify_data $ev_ids]

	array set GROUPS [_get_bet_on_qualify_data $ev_ids $type_ids $class_ids]

	for {set g_idx 0} {$g_idx < $GROUPS(nrows)} {incr g_idx} {

		# first things last, has the customer already qualified for this group
		set group_has_qualified 0
		if {[_has_qualified $cust_id $GROUPS($g_idx,qlfy_bet_id)]} {
			set group_has_qualified 1
			break
		}
		# the user matched one qlfy_bet_id that used this group, this means that they did
		# enough to qualify for that group!
		if {$group_has_qualified == 1} {
			continue
		}

		# foreach possibly qualifying area, check to see if the customer has qualified
		#
		for {set q_idx 0} {$q_idx < $GROUPS($g_idx,qual_nrows)} {incr q_idx} {

			set level_has_qualified 0

			set level_name $GROUPS($g_idx,$q_idx,level_name)
			set level_id   $GROUPS($g_idx,$q_idx,level_id)

			set cust_ccy_total [_get_cust_bet_total $acct_id $level_name $level_id]
			set cust_gbp_total [expr {$cust_ccy_total / $exch_rate}]

			if {[info exists GROUPS($g_idx,amount,$ccy_code)]} {
				set amount_to_bet_on $GROUPS($g_idx,amount,$ccy_code)
				set cust_bet_total   $cust_ccy_total
			} else {
				set amount_to_bet_on $GROUPS($g_idx,amount)
				set cust_bet_total   $cust_gbp_total
			}

			if {$cust_bet_total >= $amount_to_bet_on} {

				if {$level_has_qualified == 1} {
					continue
				}

				# customer has qualified for all events in this group, so we should mark it as such
				ob_db::exec_qry ob_video_qualify::activate_qual $cust_id $GROUPS($g_idx,qlfy_bet_id) $bet_id
				set level_has_qualified 1
			}
		}
	}

	ob_log::write_array DEBUG GROUPS

}


#
# Check qualification details for customer against tVSGroupCust, for a specified event
# cust_id -
# ev_id   -
#
proc ob_video_qualify::can_view {cust_id args} {

	set ev_id           -1
	set video_provider  ""

	foreach {name value} $args {
		switch -- $name {
			-ev_id           { set ev_id           $value }
			-video_provider  { set video_provider  $value }
		}
	}

	set video_provider [string toupper $video_provider]

	set qlfy_bet_ids [list]

	foreach {ev_ids type_ids class_ids} [_get_ev_dd_info $ev_id] {}

	# this is the list of qualification groups against which we will check to see if the
	# cust has qualified
	array set Qualify [_get_bet_on_qualify_data $ev_ids $type_ids $class_ids]

	# no qualification criteria means cust can view the stream/event!
	if {$Qualify(nrows) == 0 || $Qualify(total_amount) == 0} {
		return 1
	}

	for {set i 0} {$i < $Qualify(nrows)} {incr i} {
		set qual_vp [string toupper $Qualify($i,video_provider)]
		if {$video_provider != "" && $qual_vp != $video_provider} {
			ob_log::write INFO {no point checking this, as it is for a different provider than the one specified: $video_provider v $qual_vp}
			continue
		}
		lappend qlfy_bet_ids $Qualify($i,qlfy_bet_id)
	}

	foreach qlfy_bet_id $qlfy_bet_ids {

		if {[_has_qualified $cust_id $qlfy_bet_id]} {
			return 1
		}

	}

	return 0
}


###############################################################################
# _private
################################################################################

#
#
#
proc ob_video_qualify::_prepare_queries {} {

	ob_db::store_qry ob_video_qualify::get_qualify_data_bet_on_sub {
		select
			qb.qlfy_bet_id,
			qb.name,
			qb.amount,
			qb.video_provider_id,
			v.video_provider,
			'EVENT'   as level_name,
			qbo.ev_id      as level_id,
			qbo.qlfy_bet_on_sub_id as qlfy_bet_on_id,
			qbc.ccy_code,
			qbc.amount as ccy_amount
		from
			tVSQualifyBet   qb,
			tVSQualifyBetOnSub qbo,
			outer tVideoProvider  v,
			outer tVSQualifyBetCCy qbc
		where
			qbo.qlfy_bet_id = qb.qlfy_bet_id
		and qbc.qlfy_bet_id = qb.qlfy_bet_id
		and v.video_provider_id = qb.video_provider_id
		and qb.qlfy_bet_id      = ?
		order by
			qbo.qlfy_bet_on_sub_id
	}

	ob_db::store_qry ob_video_qualify::get_qualify_data_bet_on {
		select
			qb.qlfy_bet_id,
			qb.name,
			qb.amount,
			qb.video_provider_id,
			v.video_provider,
			qbo.ob_level   as level_name,
			qbo.ob_id      as level_id,
			qbo.qlfy_bet_on_id,
			qbc.ccy_code,
			qbc.amount as ccy_amount
		from
			tVSQualifyBet   qb,
			tVSQualifyBetOn qbo,
			outer tVideoProvider  v,
			outer tVSQualifyBetCCy qbc
		where
			qbo.qlfy_bet_id = qb.qlfy_bet_id
		and qbc.qlfy_bet_id = qb.qlfy_bet_id
		and v.video_provider_id = qb.video_provider_id
		and qb.qlfy_bet_id      = ?
		order by
			qbo.qlfy_bet_on_id
	}

	ob_db::store_qry ob_video_qualify::get_acct_info {
		select
			a.acct_id,
			c.ccy_code,
			c.exch_rate
		from
			tAcct     a,
			tCCY      c
		where
			a.cust_id = ?
		and c.ccy_code = a.ccy_code
	}

	ob_db::store_qry ob_video_qualify::get_bet_dd_info {
		select
			e.ev_id,
			e.ev_type_id,
			e.ev_class_id
		from
			tobet ob,
			tev e,
			tevoc oc
		where
			ob.bet_id = ?
		and ob.ev_oc_id = oc.ev_oc_id
		and e.ev_id = oc.ev_id
	}

	ob_db::store_qry ob_video_qualify::get_sub_qlfy_bet_id {
		select
			qb.qlfy_bet_id
		from
			tVSQualifyBet   qb,
			tVSQualifyBetOnSub qbos
		where
			qbos.qlfy_bet_id = qb.qlfy_bet_id
		and qbos.ev_id       = ?
		and qb.status       = 'A'
	}

	ob_db::store_qry ob_video_qualify::get_qual_status {
		select
			status,
			cr_date,
			bet_id
		from
			tVSGroupCust
		where
			cust_id     = ?
		and qlfy_bet_id = ?
	}

	ob_db::store_qry ob_video_qualify::get_bet_total_ev {
		select {+ORDERED}
			nvl(sum(b.stake),0) as total
		from
			tbet  b,
			tobet o,
			tevoc s
		where
			b.acct_id  = ?
		-- I assume that the following is here because the index on tbet(acct_id,cr_date) may be
		-- more useful than the one on tevoc.ev_oc_id
		and b.cr_date >= (select cr_date from tev where ev_id = ?)
		and b.bet_id   = o.bet_id
		and o.ev_oc_id = s.ev_oc_id
		and s.ev_id    = ?
	}

	ob_db::store_qry ob_video_qualify::get_bet_total_type {
		select
			nvl(sum(b.stake/b.num_selns),0) as total
		from
			tbet  b,
			tobet o,
			tevoc s,
			tev   e
		where
			b.acct_id  = ?
		and b.bet_id   = o.bet_id
		and o.ev_oc_id = s.ev_oc_id
		and e.ev_type_id = ?
		and s.ev_id    = e.ev_id
	}

	ob_db::store_qry ob_video_qualify::get_bet_total_class {
		select
			nvl(sum(b.stake/b.num_selns),0) as total
		from
			tbet  b,
			tobet o,
			tevoc s,
			tev   e
		where
			b.acct_id  = ?
		and b.bet_id   = o.bet_id
		and o.ev_oc_id = s.ev_oc_id
		and e.ev_class_id = ?
		and s.ev_id    = e.ev_id
	}

	ob_db::store_qry ob_video_qualify::activate_qual {
		insert into tVSGroupCust (
			status, cust_id, qlfy_bet_id, bet_id
		) values (
			'A', ?, ?, ?
		)
	}

	ob_db::store_qry ob_video_qualify::get_qlfy_bet_id {
		select
			qb.qlfy_bet_id
		from
			tVSQualifyBet   qb,
			tVSQualifyBetOn qbo
		where
			qbo.qlfy_bet_id = qb.qlfy_bet_id
		and qbo.ob_level    = ?
		and qbo.ob_id       = ?
		and qb.status       = 'A'
	} 300

	ob_db::store_qry ob_video_qualify::get_ev_dd_info {
		select
			ev_class_id,
			ev_type_id
		from
			tEv
		where
			ev_id = ?
	} 300

}


# Given a cust_id, we'll need the acct_id, ccy_code and exch_rate
#
proc ob_video_qualify::_get_acct_info {cust_id} {

	set rs [ob_db::exec_qry ob_video_qualify::get_acct_info $cust_id]
	if {[db_get_nrows $rs] == 0} {
		error "no acct_id for $cust_id"
	}

	set acct_id   [db_get_col $rs 0 acct_id]
	set ccy_code  [db_get_col $rs 0 ccy_code]
	set exch_rate [db_get_col $rs 0 exch_rate]

	ob_db::rs_close $rs

	return [list $acct_id $ccy_code $exch_rate]
}


# get all the event, type and class ids involved in this bet
#
#   unless "-remove_duplicates 0" is passed, it will remove all duplicates so that only unique items are in
#   each list.
#
#   returns a list with three elements: a list of ev_ids, type_ids and class_ids
#
proc ob_video_qualify::_get_bet_dd_info {bet_id args} {

	set remove_duplicates 1
	foreach {name value} $args {
		switch -- $name {
			-remove_duplicates {   set remove_duplicates $value }
		}
	}

	set ev_ids    [list]
	set type_ids  [list]
	set class_ids [list]

	set rs     [ob_db::exec_qry ob_video_qualify::get_bet_dd_info $bet_id]
	set nrows  [db_get_nrows $rs]
	for {set i 0} {$i < $nrows} {incr i} {
		set ev_id        [db_get_col $rs $i ev_id]
		set ev_type_id   [db_get_col $rs $i ev_type_id]
		set ev_class_id  [db_get_col $rs $i ev_class_id]
		ob_log::write DEBUG {found $ev_class_id, $ev_type_id, $ev_id for bet $bet_id}

		lappend ev_ids     $ev_id
		lappend type_ids   $ev_type_id
		lappend class_ids  $ev_class_id
	}

	if {$remove_duplicates} {
		# we don't really need these in order, I just want to get rid of the
		# duplicates
		set ev_ids     [lsort -unique $ev_ids]
		set type_ids   [lsort -unique $type_ids]
		set class_ids  [lsort -unique $class_ids]
	}

	return [list $ev_ids $type_ids $class_ids]
}


#
# Get the streaming group ids for a list of events that will act as a potential list of
# subscriptions (tvsqualifybetonsub).
# -ev_ids list of events in a bet
#
proc ob_video_qualify::_get_subscription_qualify_data {ev_ids args} {

	ob_log::write DEBUG {_get_subscription_qualify_data $ev_ids $args}

	set video_provider ""
	foreach {name value} $args {
		switch -- $name {
			-video_provider  {set video_provider $value}
		}
	}
	set video_provider [string toupper $video_provider]

	set qlfy_bet_ids [list]

	foreach id $ev_ids {
		set rs [ob_db::exec_qry ob_video_qualify::get_sub_qlfy_bet_id $id]
		for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
			lappend qlfy_bet_ids [db_get_col $rs $i qlfy_bet_id]
		}
	}

	return [_get_groups_data $qlfy_bet_ids $video_provider]
}


#
# Get the streaming group ids for a list of dd objects that will act as
# qualifybeton object.
#
proc ob_video_qualify::_get_bet_on_qualify_data {ev_ids ev_type_ids ev_class_ids args} {

	ob_log::write DEBUG {_get_bet_on_qualify_data $ev_ids $ev_type_ids $ev_class_ids $args}

	set video_provider ""
	foreach {name value} $args {
		switch -- $name {
			-video_provider  {set video_provider $value}
		}
	}
	set video_provider [string toupper $video_provider]

	set qlfy_bet_ids [list]
	foreach {level ids} [list EVENT $ev_ids TYPE $ev_type_ids CLASS $ev_class_ids] {
		foreach id $ids {
			set rs [ob_db::exec_qry ob_video_qualify::get_qlfy_bet_id $level $id]
			for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
				lappend qlfy_bet_ids [db_get_col $rs $i qlfy_bet_id]
			}
		}
	}

	return [_get_groups_data $qlfy_bet_ids $video_provider "bet_on"]

}


#
#
#
proc ob_video_qualify::_has_qualified {cust_id qlfy_bet_id} {

	set res [_get_qual_status $cust_id $qlfy_bet_id]

	if {[lindex $res 0] == "A"} {
		return 1
	} else {
		return 0
	}
}


# Returns a list with the following variables:
#
#    status = A, S, (a myriad of racing post nonsense)
#             A ==> the customer can view the stream
#    bet_id = the id of the bet made that finally qualifed the customer to view
#             the stream
#    cr_date = the date when the stream was made available
#
proc ob_video_qualify::_get_qual_status {cust_id qlfy_bet_id} {

	set rs [ob_db::exec_qry ob_video_qualify::get_qual_status $cust_id $qlfy_bet_id]

	if {[db_get_nrows $rs] == 0} {
		# the I wouldn't have imagined that the cr_date would be checked if
		# we don't have a stream, but *just* in case something does, give it
		# a date that it can parse
		set now [clock format [clock seconds] -format {%Y-%m-%d %H:%S}]
		return [list {-} -1 $now]
	}

	# we should never get more than one row back, as there is a unique
	# constraint on cust_id, vp_id, ev_id
	set status  [db_get_col $rs 0 status]
	set bet_id  [db_get_col $rs 0 bet_id]
	set cr_date [db_get_col $rs 0 cr_date]

	ob_log::write INFO {Found a row: status=$status bet_id=$bet_id cr_date=$cr_date}
	ob_db::rs_close $rs

	return [list $status $bet_id $cr_date]
}



# Return the amount that the customer has bet on the relevant level in the hierarchy
# It will return the amount in the *customer's* ccy
#
# Yes, get_bet_total_ev has 2 id params passed to it whereas the others have 1.
# Check the query before you judge me.
#
proc ob_video_qualify::_get_cust_bet_total {acct_id level_name level_id} {

	switch -- [string toupper $level_name] {
		CLASS   { set rs [ob_db::exec_qry ob_video_qualify::get_bet_total_class $acct_id $level_id] }
		TYPE    { set rs [ob_db::exec_qry ob_video_qualify::get_bet_total_type  $acct_id $level_id] }
		EVENT   { set rs [ob_db::exec_qry ob_video_qualify::get_bet_total_ev    $acct_id $level_id $level_id] }
		default { error "invalid level $level_name"}
	}

	set total [db_get_col $rs 0 total]
	ob_db::rs_close $rs

	return $total
}


#
#
#
proc ob_video_qualify::_get_groups_data {qlfy_bet_ids {video_provider {}} {qlfy_bet_type {}}} {


	set GROUPS(nrows) 0
	set GROUPS(total_amount) 0.0

	foreach qlfy_bet_id $qlfy_bet_ids {

		if {$qlfy_bet_type == "bet_on"} {
			set qry ob_video_qualify::get_qualify_data_bet_on
		} else {
			set qry ob_video_qualify::get_qualify_data_bet_on_sub
		}

		set rs [ob_db::exec_qry $qry $qlfy_bet_id]

		set nrows [db_get_nrows $rs]

		set c_qlfy_bet_on_id -1

		for {set i 0} {$i < $nrows} {incr i} {
			set amount         [db_get_col $rs $i amount]
			set level_name     [db_get_col $rs $i level_name]
			set level_id       [db_get_col $rs $i level_id]
			set qlfy_bet_on_id [db_get_col $rs $i qlfy_bet_on_id]

			# we could add the video provider details in the query, but that might
			# the query complicated. It is simpler to check it here!
			set qual_vp [string toupper [db_get_col $rs $i video_provider]]
			if {$video_provider != "" && $video_provider != $qual_vp} {
				continue
			}

			set idx [_index_of $qlfy_bet_id GROUPS]

			if {$idx == -1} {
				set idx [_add_group \
					$qlfy_bet_id \
					[db_get_col $rs $i name] \
					$amount \
					[db_get_col $rs $i video_provider] \
					[db_get_col $rs $i video_provider_id] \
					GROUPS]
				set GROUPS(total_amount) [expr {$GROUPS(total_amount) + $amount}]
			}

			if {$qlfy_bet_on_id != $c_qlfy_bet_on_id} {
				_add_qual $idx $level_name $level_id GROUPS
				set c_qlfy_bet_on_id $qlfy_bet_on_id
			}

			set ccy_code   [db_get_col $rs $i ccy_code]
			set ccy_amount [db_get_col $rs $i ccy_amount]
			if {$ccy_code != "" && $ccy_amount != ""} {
				_add_ccy_amount $idx $ccy_code $ccy_amount GROUPS
			}

		}
	}

	ob_log::write_array DEBUG GROUPS

	return [array get GROUPS]
}


proc ob_video_qualify::_index_of {qlfy_bet_id arr_name} {

	upvar $arr_name ARR

	if {![info exists ARR(qlfy_bet_id_idx,$qlfy_bet_id)]} {
		return -1
	}
	return $ARR(qlfy_bet_id_idx,$qlfy_bet_id)
}



proc ob_video_qualify::_add_group {qlfy_bet_id name amount video_provider video_provider_id arr_name} {

	upvar $arr_name ARR

	set idx $ARR(nrows)
	incr ARR(nrows)

	set ARR(qlfy_bet_id_idx,$qlfy_bet_id) $idx

	set ARR($idx,qlfy_bet_id)        $qlfy_bet_id
	set ARR($idx,name)               $name
	set ARR($idx,amount)             $amount
	set ARR($idx,video_provider)     $video_provider
	set ARR($idx,video_provider_id)  $video_provider_id

	set ARR($idx,qual_nrows)   0

	return $idx
}



proc ob_video_qualify::_add_qual {idx level_name level_id arr_name} {

	upvar $arr_name ARR

	set qual_idx "$idx,$ARR($idx,qual_nrows)"

	set ARR($qual_idx,level_name) $level_name
	set ARR($qual_idx,level_id)   $level_id

	incr ARR($idx,qual_nrows)
}

proc ob_video_qualify::_add_ccy_amount {idx ccy_code ccy_amount arr_name} {

	upvar $arr_name ARR

	set ARR($idx,amount,$ccy_code) $ccy_amount

}


proc ob_video_qualify::_get_ev_dd_info {ev_id} {

	set rs [ob_db::exec_qry ob_video_qualify::get_ev_dd_info $ev_id]

	set ev_class_id [db_get_col $rs 0 ev_class_id]
	set ev_type_id  [db_get_col $rs 0 ev_type_id]

	return [list\
		[list $ev_id]\
		[list $ev_type_id]\
		[list $ev_class_id]\
	]
}

