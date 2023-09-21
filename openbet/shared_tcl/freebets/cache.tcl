#
#


namespace eval ob_fbets {
}



#
#
proc ::ob_fbets::_upd_active_offers {} {

	variable CFG
	variable OFFER
	variable TRIGGER
	variable PROMO
	variable CUST_OFFER
	variable ACTION
	variable CUST_FLAGS

	if {[info exists CUST_FLAGS(user_id)] && ( $CUST_FLAGS(user_id) == $ACTION(cust_id) )  &&
	    [info exists CUST_FLAGS(req_id)]  && ( $CUST_FLAGS(req_id)  == [reqGetId] ) } {

		ob_log::write INFO {::ob_fbets::_upd_active_offers: Customer specific data already exist}

	} else {
		# This is a new request, update the cust active offers
		set CUST_OFFER(offer_ids) [list]

		set rs [ob_db::exec_qry ob_fbets::get_cust_active_offers $ACTION(cust_id) $ACTION(cust_id)]
	
		for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
	
			set offer_id [db_get_col $rs $i offer_id]
			lappend CUST_OFFER(offer_ids) $offer_id
		}
		ob_db::rs_close $rs

		set CUST_FLAGS(user_id) $ACTION(cust_id)
		set CUST_FLAGS(req_id)  [reqGetId]
	}

	# is the data recent enough not to have to update from the db?
	#
	if {
		[info exists OFFER(retrieved_at)] &&
		([clock seconds] - $OFFER(retrieved_at)) < $CFG(offer_cache_time_secs)
	} {
		return
	}

	array set OFFER    [array unset OFFER]
	array set TRIGGER  [array unset TRIGGER]

	# do we have a cached copy in shared memory? (perhaps stored there by another child)
	#
	set cache_key "ob_fbets::offer_data"
	if {![catch {
		set offer_data [asFindString $cache_key]
	}]} {
		array set OFFER   [lindex $offer_data 0]
		array set TRIGGER [lindex $offer_data 1]
		array set PROMO   [lindex $offer_data 2]
		return
	}

	# load from the db and store in shm for other children
	#
	_load_active_offers_db
	set offer_data [list [array get OFFER] [array get TRIGGER] [array get PROMO]]
	set cache_time $CFG(offer_cache_time_secs)
	asStoreString $offer_data $cache_key $cache_time
}



# Used by _upd_active_offers.
#
proc ob_fbets::_load_active_offers_db {} {

	variable OFFER
	variable TRIGGER
	variable PROMO

	array set OFFER [array unset OFFER]
	array set TRIGGER [array unset TRIGGER]
	array set PROMO   [array unset PROMO]

	set OFFER(retrieved_at) [clock seconds]
	set OFFER(offer_ids)    [list]
	set rs [ob_db::exec_qry ob_fbets::get_all_active_offers]

	set prev_offer_id ""
	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		set offer_id [db_get_col $rs $i offer_id]
		if {$offer_id != $prev_offer_id} {

			set OFFER($offer_id,start_date)         [db_get_col $rs $i start_date]
			set OFFER($offer_id,end_date)           [db_get_col $rs $i end_date]
			set OFFER($offer_id,need_qualification) [db_get_col $rs $i need_qualification]
			set OFFER($offer_id,on_settle)          [db_get_col $rs $i on_settle]
			set OFFER($offer_id,channels)           [db_get_col $rs $i channels]
			set OFFER($offer_id,lang)               [db_get_col $rs $i lang]
			set OFFER($offer_id,country_code)       [db_get_col $rs $i country_code]
			set OFFER($offer_id,max_claims)         [db_get_col $rs $i max_claims]
			set OFFER($offer_id,unlimited_claims)   [db_get_col $rs $i unlimited_claims]

			set OFFER($offer_id,trigger_ids)  [list]
			set OFFER($offer_id,ccy_codes)    [list]

			lappend OFFER(offer_ids) $offer_id
			set prev_offer_id $offer_id
		}
		set ccy_code [db_get_col $rs $i ccy_code]
		lappend OFFER($offer_id,ccy_codes) $ccy_code
	}
	ob_db::rs_close $rs

	set TRIGGER(trigger_ids) [list]
	set rs [ob_db::exec_qry ob_fbets::get_all_active_offer_triggers]

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {

		set trigger_id [db_get_col $rs $i trigger_id]

		if { ![info exists TRIGGER($trigger_id,offer_id)] } {

			set TRIGGER($trigger_id,offer_id)       [db_get_col $rs $i offer_id]
			set TRIGGER($trigger_id,type_code)      [db_get_col $rs $i type_code]
			set TRIGGER($trigger_id,rank)           [db_get_col $rs $i rank]
			set TRIGGER($trigger_id,aff_level)      [db_get_col $rs $i aff_level]
			set TRIGGER($trigger_id,aff_id)         [db_get_col $rs $i aff_id]
			set TRIGGER($trigger_id,aff_grp_id)     [db_get_col $rs $i aff_grp_id]
			set TRIGGER($trigger_id,voucher_type)   [db_get_col $rs $i voucher_type]
			set TRIGGER($trigger_id,ref_offer_id)   [db_get_col $rs $i ref_offer_id]
			set TRIGGER($trigger_id,channel_strict) [db_get_col $rs $i channel_strict]
			set TRIGGER($trigger_id,promo_code)     [db_get_col $rs $i promo_code]
			set TRIGGER($trigger_id,qualification)  [db_get_col $rs $i qualification]
			set TRIGGER($trigger_id,min_price_num)  [db_get_col $rs $i min_price_num]
			set TRIGGER($trigger_id,min_price_den)  [db_get_col $rs $i min_price_den]

			lappend TRIGGER(trigger_ids) $trigger_id
			set offer_id [db_get_col $rs $i offer_id]
			lappend OFFER($offer_id,trigger_ids) $trigger_id

			if { $TRIGGER($trigger_id,promo_code) != "" } {
				set PROMO($TRIGGER($trigger_id,promo_code),$TRIGGER($trigger_id,offer_id)) $trigger_id
			}
		}
		set ccy_code [db_get_col $rs $i ccy_code]
		set amount   [db_get_col $rs $i amount]

		if {$amount != ""} {
			set TRIGGER($trigger_id,amount,$ccy_code) $amount
		} else {
			set TRIGGER($trigger_id,amount,$ccy_code) 0.0
		}
	}
	ob_db::rs_close $rs

	ob_log::write_array DEBUG OFFER
	ob_log::write_array DEBUG TRIGGER
	ob_log::write_array DEBUG PROMO
}



#
#
proc ::ob_fbets::_upd_cust_claimed_offers {cust_id} {

	variable CFG
	variable CLAIMS

	# Do we already have this information from this customer (loaded earlier
	# in the request perhaps?)
	#
	if {
		[info exists CLAIMS(cust_id)] && $CLAIMS(cust_id) == $cust_id &&
		[info exists CLAIMS(req_id)]  && $CLAIMS(req_id)  == [reqGetId]
	} {
		ob_log::write DEBUG {Cached CLAIMS}
		ob_log::write_array DEBUG CLAIMS
		return
	}

	array set CLAIMS [array unset CLAIMS]

	set rs [ob_db::exec_qry ob_fbets::get_cust_claimed_offers $cust_id]
	set nrows [db_get_nrows $rs]
	for {set i 0} {$i < $nrows} {incr i} {
		set offer_id       [db_get_col $rs $i offer_id]
		set num_claims     [db_get_col $rs $i num_claims]
		set CLAIMS($offer_id) $num_claims
	}
	ob_db::rs_close $rs

	set CLAIMS(cust_id)    $cust_id
	set CLAIMS(req_id)     [reqGetId]
	
	ob_log::write DEBUG {Refreshed cached CLAIMS}
	ob_log::write_array DEBUG CLAIMS
}


#
#
proc ::ob_fbets::_upd_cust_called_triggers {cust_id} {

	variable CFG
	variable ACTION
	variable CALLED
	
	# Do we already have this information from this customer (loaded earlier
	# in the request perhaps?)
	#
	if {
		[info exists CALLED(cust_id)] && $CALLED(cust_id) == $cust_id &&
		[info exists CALLED(req_id)]  && $CALLED(req_id)  == [reqGetId] &&
		[info exists CALLED(actions)] && $CALLED(actions) == $ACTION(actions)
	} {
		return
	}

	array set CALLED [array unset CALLED]

	set rs [ob_db::exec_qry ob_fbets::get_cust_called_triggers $cust_id]
	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		set trigger_id        [db_get_col $rs $i trigger_id]
		set called_trigger_id [db_get_col $rs $i called_trigger_id]

		lappend CALLED(called_trigger_ids,$trigger_id) $called_trigger_id

		set CALLED($called_trigger_id,status)  [db_get_col $rs $i status]
		set CALLED($called_trigger_id,stage)   [db_get_col $rs $i stage]
	}
	ob_db::rs_close $rs

	set CALLED(cust_id) $cust_id
	set CALLED(req_id)  [reqGetId]
	set CALLED(actions) $ACTION(actions)
	ob_log::write_array DEBUG CALLED
}



proc ::ob_fbets::_prepare_cache_queries {} {

	# uncached, since cacheing is done on the resulting array
	ob_db::store_qry ob_fbets::get_all_active_offers {
		select
			o.offer_id,
			o.start_date,
			NVL(o.end_date, '2029-12-31 23:59:59') as end_date,
			o.need_qualification,
			o.on_settle,
			o.channels,
			o.lang,
			o.country_code,
			o.max_claims,
			o.unlimited_claims,
			oc.ccy_code
		from
			tOffer    o,
			tOfferCCY oc
		where
			    o.start_date <= CURRENT
			and (o.end_date is null or o.end_date >= CURRENT)
			and o.offer_id   =  oc.offer_id
		order by o.offer_id
	}

	# uncached, since cacheing is done on the resulting array
	# important that this is ordered by rank as the code relies on this
	ob_db::store_qry ob_fbets::get_all_active_offer_triggers {
		select
			o.offer_id,
			t.trigger_id,
			t.type_code,
			t.rank,
			t.aff_level,
			t.aff_id,
			t.aff_grp_id,
			t.voucher_type,
			t.ref_offer_id,
			t.channel_strict,
			t.promo_code,
			t.min_price_num,
			t.min_price_den,
			tt.qualification,
			ta.ccy_code,
			ta.amount
		from
			tOffer         o,
			tTrigger       t,
			tTriggerType   tt,
			tTriggerAmount ta
		where
			    o.start_date <= CURRENT
			and (o.end_date is null or o.end_date >= CURRENT)
			and o.offer_id   =  t.offer_id
			and t.type_code  =  tt.type_code
			and t.trigger_id =  ta.trigger_id
		order by t.rank
	}

	# NB: debatable whether it's better to join to tOffer to filter
	# by active offers or not - we're not expecting many anyway.
	# uncacheable - needs to be up-to-date.
	ob_db::store_qry ob_fbets::get_cust_claimed_offers {
		select
			co.offer_id,
			count(co.claimed_offer_id) as num_claims
		from
			tClaimedOffer co
		where
			co.cust_id = ?
		group by
			1
	}

	# uncacheable - needs to be up-to-date.
	ob_db::store_qry ob_fbets::get_cust_called_triggers {
		select
			ct.called_trigger_id,
			ct.trigger_id,
			ct.status,
			ct.stage
		from
			tCalledTrigger ct,
			tTrigger       t,
			tOffer         o
		where
			    ct.cust_id    =  ?
			and ct.trigger_id =  t.trigger_id
			and ct.status     = 'A'
			and t.offer_id    =  o.offer_id
			and o.start_date  <= CURRENT
			and (o.end_date is null or o.end_date >= CURRENT)
	}

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

	set get_cust_active_offers_qry {
 		select
			o.offer_id
		from
			tOffer         o,
			tCustomer      cu,
			tCustomerReg   cr
		where
			cu.cust_id = ?
			and cr.cust_id = cu.cust_id
			and o.start_date <= CURRENT
			and (o.end_date is null or o.end_date >= CURRENT)
			and
			(
				(o.entry_expiry_date is null or o.entry_expiry_date >= CURRENT)
				or
				(exists
					(select
						1
					from
						tCalledTrigger  ct,
						tTrigger t
					where
						t.offer_id     = o.offer_id
						and ct.trigger_id  = t.trigger_id
						and ct.status      = 'A'
						and ct.cust_id     = cu.cust_id
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
			$cust_code_where
			and (
				cu.elite = o.elite_only
				or o.elite_only = 'N'
			)
	}

	# Get active offers - eliminating expired ones etc - for a customer
	ob_db::store_qry ob_fbets::get_cust_active_offers [subst $get_cust_active_offers_qry]
}