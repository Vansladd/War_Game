# $Id: wap_dd_qry.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
#
# WAP Database Queries
# WAP enabled queries to do the drill down through the Event hierachy.
#
# USE:
# namespace import OB_wap_dd::*
# before using any of the procedures must call init_wap_dd
#
# Required Config values:
# DB_CACHE cache time (seconds - default 0)
#          overridden by DB_NO_CACHE
#
#
#
# Include:
# shared_tcl/err.tcl
# shared_tcl/db.qry
# shared_tcl/util.qry
#
#


namespace eval OB_wap_dd {

	namespace export DB_CACHE

	namespace export EV_TYPES
	namespace export EVENTS
	namespace export EV_OUTCOMES
	namespace export MARKETS

	namespace export init_wap_dd

	namespace export get_ev_class
	namespace export get_ev_type
	namespace export get_event
	namespace export get_market
	namespace export get_ev_outcome
}

#
# initialise
#
proc OB_wap_dd::init_wap_dd {} {

	global DB_CACHE
	variable CFG

	set DB_CACHE [OT_CfgGet DB_CACHE "0"]
	ob::log::write DEV {init_wap_dd: DB_CACHE=$DB_CACHE}

	set CFG(SOURCE) "*[OT_CfgGet CHANNEL "W"]*"

	prepare_wap_dd_class_queries
	prepare_wap_dd_ev_type_queries
	prepare_wap_dd_event_queries
	prepare_wap_dd_market_queries
	prepare_wap_dd_ev_outcome_queries
}


#
# prepare class queries
#
proc OB_wap_dd::prepare_wap_dd_class_queries {} {

	global DB_CACHE EV_CLASSES

	set EV_CLASSES(fields)    { class_name sort fastkey disporder ev_class_id category status }
	set EV_CLASSES(xl_fields) { class_name category }

	# get all the WAP enabled class (ordered by fastkey) which have at least 1 event
	db_store_qry dd_ev_class_ofk {
		select
			c.name as class_name, c.sort, c.fastkey, c.disporder, c.ev_class_id, c.category, c.status
		from
			tEvClass c
		where
			c.channels matches ? and
			c.displayed = 'Y' and
			c.fo_avail = 'Y' and
			exists (
					select 1
					from
						tEvType t, tEv e,
						tEvUnstl    un
					where
						un.ev_id         = e.ev_id and
						t.ev_class_id = c.ev_class_id and
						un.ev_type_id = t.ev_type_id and

						pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'Y' and

						t.channels matches ? and
						e.channels matches ? and
						t.displayed = 'Y' and
						e.displayed = 'Y' and
						e.result_conf = 'N' and
						t.fo_avail = 'Y' and
						e.fo_avail = 'Y'
			)
		order by
			c.fastkey, c.disporder, class_name
	} $DB_CACHE

	# get all the WAP enabled class which have at least 1 event
	db_store_qry dd_ev_class {
		select
			c.name as class_name, c.sort, c.fastkey, c.disporder, c.ev_class_id, c.category, c.status
		from
			tEvClass c
		where
			c.channels matches ? and
			c.displayed = 'Y' and
			c.fo_avail = 'Y' and
			exists (
					select 1
						from tEvType t, tEv e,
						tEvUnstl    un
					where
						un.ev_id         = e.ev_id and
						t.ev_class_id = c.ev_class_id and
						un.ev_type_id = t.ev_type_id and
						pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'Y' and
						t.channels matches ? and
						e.channels matches ? and
						t.displayed = 'Y' and
						e.displayed = 'Y' and
						e.result_conf = 'N' and
						t.fo_avail = 'Y' and
						e.fo_avail = 'Y'
			)
		order by
			c.disporder, class_name
	} $DB_CACHE

	# get a particular WAP enabled class which have at least 1 event
	db_store_qry dd_ev_class_id {
		select
			c.name as class_name, c.sort, c.fastkey, c.disporder, c.ev_class_id, c.category, c.status
		from
			tEvClass c
		where
			c.ev_class_id = ? and
			c.channels matches ? and
			c.displayed = 'Y' and
			c.fo_avail = 'Y' and
			exists (
				select 1
					from tEvType t, tEv e,
					tEvUnstl    un
				where
					un.ev_id         = e.ev_id and
					t.ev_class_id = c.ev_class_id and
					un.ev_type_id = t.ev_type_id and

					pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'Y' and

					t.channels matches ? and
					e.channels matches ? and
					t.displayed = 'Y' and
					e.displayed = 'Y' and
					e.result_conf = 'N' and
					t.fo_avail = 'Y' and
					e.fo_avail = 'Y'

				)
		order by
			c.disporder, class_name
	} $DB_CACHE

	# get a WAP enabled class for a particular fastkey which have at least 1 event
	db_store_qry dd_ev_class_fk {
		select
			c.name as class_name, c.sort, c.fastkey, c.disporder, c.ev_class_id, c.category, c.status
		from
			tEvClass c
		where
			c.fastkey = ? and
			c.channels matches ? and
			c.displayed = 'Y' and
			c.fo_avail = 'Y' and
			exists (
					select 1
					from tEvType t, tEv e,
					tEvUnstl    un
					where
						un.ev_id         = e.ev_id and
						t.ev_class_id = c.ev_class_id and
						un.ev_type_id = t.ev_type_id and
						pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'Y' and
						t.channels matches ? and
						e.channels matches ? and
						t.displayed = 'Y' and
						e.displayed = 'Y' and
						e.result_conf = 'N' and
						t.fo_avail = 'Y' and
						e.fo_avail = 'Y'
			)
		order by
			c.disporder, class_name
	} $DB_CACHE

	# get all the WAP enabled class for a particular category which have at least 1 event
	db_store_qry dd_ev_class_category {
		select
			c.name as class_name, c.sort, c.fastkey, c.disporder, c.ev_class_id, c.category, c.status
		from
			tEvClass c
		where
			c.category = ? and
			c.channels matches ? and
			c.displayed = 'Y' and
			c.fo_avail = 'Y' and
			exists (
					select 1
						from tEvType t, tEv e,
						tEvUnstl    un
					where
						un.ev_id         = e.ev_id and
						t.ev_class_id = c.ev_class_id and
						un.ev_type_id = t.ev_type_id and
						pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'Y' and
						t.channels matches ? and
						e.channels matches ? and
						t.displayed = 'Y' and
						e.displayed = 'Y' and
						e.result_conf = 'N' and
						t.fo_avail = 'Y' and
						e.fo_avail = 'Y'
			)
		order by
			c.disporder, class_name
	} $DB_CACHE
}



#
# prepare ev_type queries
#
proc OB_wap_dd::prepare_wap_dd_ev_type_queries {} {

	global DB_CACHE EV_TYPES

	set EV_TYPES(fields)         { ev_type_id type_name fastkey disporder status }
	set EV_TYPES(xl_fields)      { type_name }

	# get all the WAP enabled event types (ordered by fastkey) which have at least 1 event
	db_store_qry dd_ev_types_ofk {
		select
			t.ev_type_id, t.name as type_name, t.fastkey, t.disporder, t.status
		from
			tEvType t
		where
			t.ev_class_id = ? and
			t.channels matches ? and
			t.displayed = 'Y' and
			t.fo_avail = 'Y' and
		exists (
			select 1
			from tEv e,
			tEvUnstl    un
			where
				un.ev_id         = e.ev_id and
				un.ev_type_id = t.ev_type_id and
				pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'Y' and
				e.channels matches ? and
				e.displayed = 'Y' and
				e.result_conf = 'N' and
				e.fo_avail = 'Y'
		)
		order by
			t.fastkey, t.disporder, type_name
	} $DB_CACHE

	# get all the WAP enabled event types which have at least 1 event
	db_store_qry dd_ev_types {
		select
			t.ev_type_id, t.name as type_name, t.fastkey, t.disporder, t.status
		from
			tEvType t
		where
			t.ev_class_id = ? and
			t.channels matches ? and
			t.displayed = 'Y' and
			t.fo_avail = 'Y' and
			exists (
				select 1
				from tEv e,
				tEvUnstl    un
				where
					un.ev_id         = e.ev_id and
					un.ev_type_id = t.ev_type_id and
					and pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'Y' and
					e.channels matches ? and
					e.displayed = 'Y' and
					e.result_conf = 'N' and
					e.fo_avail = 'Y'
			)
		order by
			t.disporder, type_name
	} $DB_CACHE

	# get all WAP enabled category event types which have at least 1 event
	db_store_qry dd_cat_ev_types {
		select
			t.ev_type_id, t.name as type_name, t.fastkey, t.disporder, t.status
		from
			tEvType t, tEvClass c
		where
			c.category = ? and
			c.sort = ? and
			t.ev_class_id = c.ev_class_id and
			t.channels matches ? and
			t.displayed = 'Y' and
			c.fo_avail = 'Y' and
			t.fo_avail = 'Y' and
			exists (
				select 1
				from tEv e,
				tEvUnstl    un
				where
					un.ev_id         = e.ev_id and
					un.ev_type_id = t.ev_type_id and
					pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'Y' and
					e.channels matches ? and
					e.displayed = 'Y' and
					e.result_conf = 'N' and
					e.fo_avail = 'Y'
			)
		order by
			t.disporder, type_name
	} $DB_CACHE

	# get a WAP enabled event_type_id for a particular fastkey which have at least 1 event
	db_store_qry dd_ev_type_fk {
		select
			t.ev_type_id, t.name as type_name, t.fastkey, t.disporder, t.status
		from
			tEvType t
		where
			t.ev_class_id = ? and
			t.fastkey = ? and
			t.channels matches ? and
			t.displayed = 'Y' and
			t.fo_avail = 'Y' and
			exists (
				select 1
				from tEv e,
				tEvUnstl    un
				where
					un.ev_id         = e.ev_id and
					un.ev_type_id = t.ev_type_id and

					pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'Y' and

					e.channels matches ? and
					e.displayed = 'Y' and
					e.result_conf = 'N' and
					e.fo_avail = 'Y'
			)
		order by
			t.disporder, type_name
	} $DB_CACHE

	# get a single event type
	db_store_qry dd_ev_type {
		select
			t.ev_type_id, t.name as type_name, t.fastkey, t.disporder, t.status
		from
			tEvType t
		where
			t.ev_type_id = ?
	} $DB_CACHE
	db_store_qry dd_ev_type_ev {
		select
			t.ev_type_id, t.name as type_name, t.fastkey, t.disporder, t.status
		from
			tEvType t
		where
			t.ev_type_id = (select ev_type_id from tev where ev_id = ?)
	} $DB_CACHE
}



#
# prepare event queries
#
proc OB_wap_dd::prepare_wap_dd_event_queries {} {

	global EVENTS

	set EVENTS(fields)         { ev_id event_name fastkey status started start_time }
	set EVENTS(xl_fields)      { event_name }

	# get all the WAP enabled events for a particular event_type_id (order by fastkey)
	db_store_qry dd_events_ofk {
		select
			e.ev_id, e.desc as event_name, e.fastkey, e.disporder, e.start_time, e.status,
			case
				when pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'N'
				then 'Y'
				else 'N'
			end as started
		from
			tEv e,
			tEvUnstl    un
		where
			un.ev_id         = e.ev_id and
			un.ev_type_id = ? and
			e.channels matches ? and
			and pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'Y' and
			e.displayed = 'Y' and
			e.sort in ('MTCH','TNMT') and
			e.result_conf = 'N' and
			e.fo_avail = 'Y'
		order by
			e.fastkey, e.disporder, e.start_time, e.event_name
	}

	# get all the WAP enabled events for a particular event_type_id
	db_store_qry dd_event {
		select
			e.ev_id, e.desc as event_name, e.fastkey, e.disporder, e.start_time, e.status,
			case
				when pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'N'
				then 'Y'
				else 'N'
			end as started
		from
			tEv e,
			tEvUnstl    un
		where
			un.ev_type_id = ? and
			un.ev_id         = e.ev_id and
			e.channels matches ? and

			pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'Y' and

			e.displayed = 'Y' and
			e.sort in ('MTCH','TNMT') and
			e.result_conf = 'N' and
			e.fo_avail = 'Y'
		order by
			e.disporder, e.start_time, e.event_name
	}

	# get a WAP enabled event_id for a particular fastkey
	db_store_qry dd_event_fk {
		select
			e.ev_id, e.desc as event_name, e.fastkey, e.disporder, e.start_time, e.status,
			case
				when pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'N'
				then 'Y'
				else 'N'
			end as started
		from
			tEv e,
			tEvUnstl    un
		where
			un.ev_id         = e.ev_id and
			un.ev_type_id = ? and
			e.fastkey = ? and
			e.channels matches ? and

			pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'Y' and

			e.displayed = 'Y' and
			e.sort in ('MTCH','TNMT') and
			e.result_conf = 'N' and
			e.fo_avail = 'Y'
		order by
			e.disporder, e.start_time, e.event_name
	}

	# get a single WAP enabled event
	db_store_qry dd_event_id {
		select
			e.ev_id, e.desc as event_name, e.fastkey, e.disporder, e.start_time, e.status,
			case
				when pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'N'
				then 'Y'
				else 'N'
			end as started
		from
			tEv e
		where
			e.ev_id = ?
	}
	db_store_qry dd_event_id_mkt {
		select
			e.ev_id, e.desc as event_name, e.fastkey, e.disporder, e.start_time, e.status,
			case
				when pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'N'
				then 'Y'
				else 'N'
			end as started
		from
			tEv e
		where
			ev_id = (select ev_id from tevmkt where ev_mkt_id=?)
	}
}


#
# prepare market queries
#
proc OB_wap_dd::prepare_wap_dd_market_queries {} {

	global MARKETS

	set MARKETS(fields)         { mkt_name evocgrp_blurb ev_mkt_id sort disporder status started }
	set MARKETS(xl_fields)      { mkt_name evocgrp_blurb }

	# get all the WAP enabled markets for a particular event
	db_store_qry dd_market {
		select
			m.ev_mkt_id, m.disporder, m.sort, m.status,
			m.name as mkt_name, g.blurb as evocgrp_blurb,
			case
				when pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'N'
				then 'Y'
				else 'N'
			end as started
		from
			tEvMkt m, tEvOcGrp g, tEv e, tEvUnstl    un
		where
			e.ev_id = ? and
			un.ev_id         = e.ev_id and
			pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'Y' and
			e.channels matches ? and
			e.displayed = 'Y' and
			e.result_conf = 'N' and
			m.ev_id = e.ev_id and
			m.channels matches ? and
			m.displayed = 'Y' and
			g.ev_oc_grp_id = m.ev_oc_grp_id and
			g.channels matches ? and
			g.fo_avail = 'Y' and
			e.fo_avail = 'Y' and
			m.fo_avail = 'Y'
		order by
			m.disporder, mkt_name
	}

	# get a market
		db_store_qry dd_market_mkt_id {
		select
			m.ev_mkt_id, m.disporder, m.sort, m.status,
			m.name as mkt_name, g.blurb as evocgrp_blurb,
			case
				when pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'N'
				then 'Y'
				else 'N'
			end as started
		from
			tEvMkt m, tEvOcGrp g, tEv e, tEvUnstl    un
		where
			m.ev_mkt_id = ? and
			un.ev_id         = e.ev_id and
			m.channels matches ? and
			m.displayed = 'Y' and
			e.ev_id = m.ev_id and
			pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'Y' and
			e.channels matches ? and
			e.displayed = 'Y' and
			e.result_conf = 'N' and
			g.ev_oc_grp_id = m.ev_oc_grp_id and
			g.channels matches ? and
			g.fo_avail = 'Y' and
			e.fo_avail = 'Y' and
			m.fo_avail = 'Y'
	}
}


#
# prepare outcomes queries
#
proc OB_wap_dd::prepare_wap_dd_ev_outcome_queries {} {

	global EV_OUTCOMES

	set EV_OUTCOMES(fields) { ev_oc_id oc_name status fb_result cs_home cs_away ew_avail ew_places ew_fac lp_avail lp_num lp_den price_type sp_avail started }
	set EV_OUTCOMES(xl_fields) { oc_name }

	# get all the WAP enabled event outcomes for a particular event and ocgrp sort
	db_store_qry dd_ev_outcomes_ocgrp {
		select
			m.lp_avail, m.sp_avail, m.ew_avail, m.ew_fac_num, m.ew_fac_den, m.ew_places, m.sort as mkt_sort,
			o.fb_result, o.cs_home, o.cs_away, o.ev_oc_id, o.desc as oc_name, o.lp_num, o.lp_den, o.disporder,
			o.lp_num/o.lp_den as decimal_price,
			decode(m.status||nvl(o.status, 'A'), 'AA', 'A', 'S') as status,
			case
				when pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'N'
				then 'Y'
				else 'N'
			end as started
		from
			tEv e, tEvmkt m, tEvOc o, tEvOcGrp g, tEvUnstl    un
		where
			e.ev_id = ? and
			g.sort = ? and
			un.ev_id         = e.ev_id and
			pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'Y' and
			e.displayed = 'Y' and
			e.channels matches ? and
			e.result_conf = 'N' and
			m.ev_id = e.ev_id and
			m.ev_oc_grp_id = g.ev_oc_grp_id and
			m.displayed = 'Y' and
			m.channels matches ? and
			o.ev_mkt_id = m.ev_mkt_id and
			o.displayed = 'Y' and
			o.channels matches ? and
			o.desc != '' and
			g.fo_avail = 'Y' and
			e.fo_avail = 'Y' and
			m.fo_avail = 'Y' and
			o.fo_avail = 'Y'
		order by
			o.disporder, decimal_price, oc_name
	}

	# get all the WAP enabled outcomes for a particular market
	db_store_qry dd_mkt_ev_outcome {
		select
			m.lp_avail, m.sp_avail, m.ew_avail, m.ew_fac_num, m.ew_fac_den, m.ew_places, m.sort as mkt_sort,
			o.fb_result, o.cs_home, o.cs_away, o.ev_oc_id, o.desc as oc_name, o.lp_num, o.lp_den, o.disporder,
			o.lp_num/o.lp_den as decimal_price,
			decode(m.status||nvl(o.status, 'A'), 'AA', 'A', 'S') as status,

			case
				when pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'N'
				then 'Y'
				else 'N'
			end as started
		from
			tEvmkt m, tEvOc o, tEv e
		where
			m.ev_mkt_id = ? and
			m.displayed = 'Y' and
			m.channels matches ? and
			m.ev_id = e.ev_id and
			o.ev_mkt_id = m.ev_mkt_id and
			o.displayed = 'Y' and
			o.channels matches ? and
			o.desc != '' and
			e.fo_avail = 'Y' and
			m.fo_avail = 'Y' and
			o.fo_avail = 'Y'
		order by
			o.disporder, decimal_price, oc_name
	}
}



#
# store WAP enabled event class[es] into a global array EV_CLASSES
# returns 1 on success, 0 on error (error messages stored in err-list)
#
proc OB_wap_dd::get_ev_class { {search_by -none} {id ""} {order_by_fastkey "N"} } {

	global EV_CLASSES
	variable CFG

	set EV_CLASSES(total) 0

	if {$search_by == "-none"} {
		if {$order_by_fastkey == "Y"} {
			set qry dd_ev_class_ofk
		} elseif {$order_by_fastkey == "N"} {
			set qry dd_ev_class
		} else {
			error "get_ev_classes: unknown option (order_by_fastkey=$order_by_fastkey)"
		}
	} elseif {$search_by == "-ev_class_id"} {
		set qry dd_ev_class_id
	} elseif {$search_by == "-fastkey"} {
		set qry dd_ev_class_fk
	} elseif {$search_by == "-category"} {
		set qry dd_ev_class_category
	} else {
		error "get_ev_classes: unknown option (search_by=$search_by)"
	}

	if {$id == ""} {
		set id $CFG(SOURCE)
	}

	if {[catch {set rs [db_exec_qry $qry $id $CFG(SOURCE) $CFG(SOURCE) $CFG(SOURCE)]} msg]} {
		ob::log::write ERROR {get_ev_classes: $msg}
		err_add "Unable to get event class\[es\]."
		err_add $msg
		return 0
	}
	set EV_CLASSES(total) [db_get_nrows $rs]
	for {set i 0} {$i < $EV_CLASSES(total)} {incr i} {
		foreach f $EV_CLASSES(fields) { set EV_CLASSES($i,$f) [db_get_col $rs $i $f] }
		foreach f $EV_CLASSES(xl_fields) { set EV_CLASSES($i,$f) [XL $EV_CLASSES($i,$f)] }
	}
	db_close $rs

	return 1
}




#
# store WAP enabled event type[s] into a global array EV_TYPES
# returns 1 on success, 0 on error (error messages stored in err-list)
#
proc OB_wap_dd::get_ev_type { search_by id {id2 ""} {order_by_fastkey "N"} } {

	global EV_TYPES
	variable CFG

	set EV_TYPES(total) 0

	if {$search_by == "-ev_class_id"} {
		if {$order_by_fastkey == "Y"} {
			set qry dd_ev_types_ofk
		} elseif {$order_by_fastkey == "N"} {
			set qry dd_ev_types
		} else {
			error "get_ev_type: Unknown option (order_by_fastkey=$order_by_fastkey)"
		}
	} elseif {$search_by == "-category"} {
		set qry dd_cat_ev_types
	} elseif {$search_by == "-fastkey"} {
		set qry dd_ev_type_fk
	} elseif {$search_by == "-ev_type_id"} {
		set qry dd_ev_type
	} elseif {$search_by == "-ev_id"} {
		set qry dd_ev_type_ev
	} else {
		error "get_ev_type: Unknown option (search_by=$search_by)"
	}

	if {$id2 == ""} {
		set id2 $CFG(SOURCE)
	}

	if {[catch {set rs [db_exec_qry $qry $id $id2 $CFG(SOURCE) $CFG(SOURCE)]} msg]} {
		ob::log::write ERROR {get_ev_type: $msg}
		err_add "Unable to get event types"
		err_add $msg
		return 0
	}
	set EV_TYPES(total) [db_get_nrows $rs]
	for {set i 0} {$i < $EV_TYPES(total)} {incr i} {
		foreach f $EV_TYPES(fields) { set EV_TYPES($i,$f) [db_get_col $rs $i $f] }
		foreach f $EV_TYPES(xl_fields) { set EV_TYPES($i,$f) [XL $EV_TYPES($i,$f)] }
	}
	db_close $rs

	return 1
}





#
# store WAP enabled event[s] into a global array EVENTS
# returns 1 on success, 0 on error (error messages stored in err-list)
#
proc OB_wap_dd::get_event { search_by id {id2 ""} {order_by_fastkey "N"} } {

	global EVENTS
	variable CFG

	set EVENTS(total) 0

	if {$search_by == "-ev_type_id"} {
		if {$order_by_fastkey == "Y"} {
			set qry "dd_events_ofk"
		} elseif {$order_by_fastkey == "N"} {
			set qry "dd_event"
		} else {
			error "get_event: Unknown option (order_by_fastkey=$order_by_fastkey)"
		}
	} elseif {$search_by == "-fastkey"} {
		set qry "dd_event_fk"
	} elseif {$search_by == "-ev_id"} {
		set qry "dd_event_id"
	} elseif {$search_by == "-ev_mkt_id"} {
		set qry "dd_event_id_mkt"
	} else {
		error "get_event: Unknown option (search_by=$search_by)"
	}

	if {$id2 == ""} {
		set id2 $CFG(SOURCE)
	}

	if {[catch {set rs [db_exec_qry $qry $id $id2 $CFG(SOURCE)]} msg]} {
		ob::log::write ERROR {get_event: $msg}
		err_add "Unable to get events"
		err_add $msg
		return 0
	}
	set EVENTS(total) [db_get_nrows $rs]
	for {set i 0} {$i < $EVENTS(total)} {incr i} {
		foreach f $EVENTS(fields) { set EVENTS($i,$f) [db_get_col $rs $i $f] }
		foreach f $EVENTS(xl_fields) { set EVENTS($i,$f) [XL $EVENTS($i,$f)] }
	}
	db_close $rs

	return 1
}



#
# store WAP enabled market[s] into a global array MARKETS
# returns 1 on success, 0 on error (error messages stored in err-list)
#
proc OB_wap_dd::get_market { search_by id } {

	global MARKETS
	variable CFG

	set MARKETS(total) 0

	if {$search_by == "-ev_id"} {
		set qry dd_market
	} elseif {$search_by == "-ev_mkt_id"} {
		set qry dd_market_mkt_id
	} else {
		error "get_market: Unknown option (search_by=$search_by)"
	}

	if {[catch {set rs [db_exec_qry $qry $id $CFG(SOURCE) $CFG(SOURCE) $CFG(SOURCE)]} msg]} {
		ob::log::write ERROR {get_market: $msg}
		err_add "Unable to get markets."
		err_add $msg
		return 0
	}
	set MARKETS(total) [db_get_nrows $rs]
	for {set i 0} {$i < $MARKETS(total)} {incr i} {
		foreach f $MARKETS(fields) { set MARKETS($i,$f) [db_get_col $rs $i $f] }
		foreach f $MARKETS(xl_fields) { set MARKETS($i,$f) [XL $MARKETS($i,$f)] }
	}
	db_close $rs

	return 1
}





#
# store all the WAP enabled event ouctcomes into a global array EV_OUTCOMES
# returns 1 on success, 0 on error (error messages stored in err-list)
#
proc OB_wap_dd::get_ev_outcome { search_by id {id2 ""} } {

	global EV_OUTCOMES
	variable CFG

	set EV_OUTCOMES(total) 0

	if {$search_by == "-ev_id_ocgrp"} {
		set qry dd_ev_outcomes_ocgrp
	} elseif {$search_by == "-ev_mkt_id"} {
		set qry dd_mkt_ev_outcome
	} else {
		error "get_ev_outcome: Unknown option (search_by=$search_by)"
	}

	if {$id2 == ""} {
		set id2 $CFG(SOURCE)
	}

	if {[catch {set rs [db_exec_qry $qry $id $id2 $CFG(SOURCE) $CFG(SOURCE) $CFG(SOURCE)]} msg]} {
		ob::log::write ERROR {get_ev_outcomes: $msg}
		err_add "Unable to get event outcomes"
		err_add $msg
		return 0
	}
	set EV_OUTCOMES(total) [db_get_nrows $rs]
	for {set i 0} {$i < $EV_OUTCOMES(total)} {incr i} {
		foreach f $EV_OUTCOMES(fields) {
			if {$f != "ew_fac" && $f != "price_type"} { set EV_OUTCOMES($i,$f) [db_get_col $rs $i $f] }
		}
		foreach f $EV_OUTCOMES(xl_fields) { set EV_OUTCOMES($i,$f) [XL $EV_OUTCOMES($i,$f)] }

		if {$EV_OUTCOMES($i,lp_avail) == "Y" && $EV_OUTCOMES($i,lp_num) != "" && $EV_OUTCOMES($i,lp_den) != ""} {
			set EV_OUTCOMES($i,price_type) "$EV_OUTCOMES($i,lp_num)/$EV_OUTCOMES($i,lp_den)"
		} elseif {$EV_OUTCOMES($i,sp_avail) == "Y" } {
			set EV_OUTCOMES($i,price_type) "SP"
		} else {
			set EV_OUTCOMES($i,price_type) "??"
		}
		if {$EV_OUTCOMES($i,ew_avail) == "Y"} {
			set EV_OUTCOMES($i,ew_fac) \
				"[db_get_col $rs $i ew_fac_num]/[db_get_col $rs $i ew_fac_den]"
		} else {
			set EV_OUTCOMES($i,ew_fac) ""
		}
	}
	db_close $rs

	return 1
}



