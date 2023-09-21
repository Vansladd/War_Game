# $Id: dd_qry.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
# ==============================================================
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
#
# This file contains the sql queries to do the drill down
# through the Event hierachy.
#
# Some simple wrappers around the queries sheild the user
# from some implementation detail
# ==============================================================
# FUNCTIONS
# --------------------------------------------------------------
#   init_dd {}
#
#   prep_dd_qrys {}
#
#   handle_err args
#
#   get_current {}
#     get_current_date
#
#   ob_get_classes {{class_sort "%"} {category "%"} {period "FUTURE"} {channel "I"}}
#     get_classes
#
#   ob_get_classes_and_types {{class_sort "%"} {category "%"} {period "FUTURE"} {channel "I"}}
#     get_category_types_and_coupons
#
#   ob_get_types_and_coupons {class {period "FUTURE"} {channel "I"}}
#     get_class_types_and_coupons
#
#   ob_get_types {class {period "FUTURE"} {channel "I"}
#     get_types
#
#   ob_get_current_types {class}
#     get_current_types
#
#   ob_get_coupons {class {period "FUTURE"} {channel "I"}}
#     get_coupons
#
#   ob_get_coupon {coupon {period "FUTURE"} {channel "I"}}
#     get_coupon
#
#   ob_get_coupon_head {coupon}
#     get_coupon_head
#
#   ob_get_coupon_selns {coupon {channel "I"}}
#     get_coupon_selns
#
#   ob_get_coupon_for_event_type {ev_type_id {mkt_sort "MR"} {period "FUTURE"} {channel "I"}}
#     get_coupon_fut_for_event_type
#
#   ob_get_mkts_for_ev {event {period "FUTURE"} {channel "I"}}
#     get_mkts_for_ev
#
#   ob_get_mkt_selns_for_ev {mkt {period "FUTURE"} {channel "I"}}
#     get_mkt_selns_for_ev
#
#   ob_get_events_for_oc_grp {mkt {period "FUTURE"} {channel "I"}}
#     get_events_for_oc_grp
#
#   ob_get_event_list_for_type {type {period "FUTURE"} {channel "I"}}
#     get_events_for_type
#
#   ob_get_event_list_for_type_btwn_dates {type date {period "FUTURE"} {channel "I"}}
#     get_events_for_type_btwn_dates
#
#   ob_get_mkt_list_for_type {type {period "FUTURE"} {channel "I"}}
#     get_mkt_list_for_type
#
#   ob_get_mkt_list_for_ev {event {period "FUTURE"} {channel "I"}}
#     get_mkt_list_for_event
#
#   ob_get_mkts_for_ev_without_sc {event {period "FUTURE"} {channel "I"}}
#     get_mkt_list_for_event_without_sc
#
#   ob_get_mkt_list_for_ev_with_blurbs {event {period "FUTURE"} {channel "I"}}
#     get_mkt_list_for_event_with_blurbs
#
#   ob_get_ev_mkt_list_for_type {type {period "FUTURE"} {channel "I"}}
#     get_event_mkt_list_for_type
#
#   ob_get_selns_for_mkt {mkt {channel "I"}}
#     get_selns_for_mkt
#
#   ob_get_all_active_types {}
#     get_all_active_types

proc init_dd {} {
  prep_dd_qrys
}

proc prep_dd_qrys {} {

  db_store_qry get_current_date {
	select first 1
		 extend (current, year to second)
	from
		 systables
  }

  # --------------------------------------------
  # query to retrieve all classes optionally for
  # a given category
  #
  # this query currently attempts to handle all
  # cases past/future etc
  # --------------------------------------------

  db_store_qry get_classes {
	select distinct
		c.category,
		c.ev_class_id,
		c.sort as ev_class_sort,
		c.name as class_name,
		c.blurb,
		x.xl_blurb_1,
		x.xl_blurb_2,
		x.xl_blurb_3,
		c.disporder

	from
		tevclass  c,
		tevtype   t,
		outer tblurbxlate x

	where
		c.sort          like ?
		and   c.category      like ?
		and   t.ev_class_id   = c.ev_class_id

		and exists (
			select
				e.ev_id
			from
				tev e,
				tEvUnstl u
			where
				u.ev_type_id  = t.ev_type_id
				and u.ev_id         = e.ev_id
				and    e.displayed   = t.displayed

				and pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'Y'

				and    e.result_conf   = 'N'
				and    e.fo_avail = 'Y'
				and    e.channels    like ?

				and    exists (
					select
						m.ev_mkt_id
					from
						tEvMkt m
					where
						e.ev_id = m.ev_id
						and    m.displayed = e.displayed
						and    m.channels  like ?
						and    m.channels  like ?
						and    m.fo_avail = 'Y'
				)
		)

		and   x.ref_id        = c.ev_class_id
		and   x.sort          = 'CLASS'

		and   c.displayed     = 'Y'
		and   t.displayed     = 'Y'

		and   c.fo_avail = 'Y'
		and   t.fo_avail = 'Y'

		and   c.channels      like ?
		and   t.channels      like ?

		and   x.lang          = ?

	order by
		c.disporder,
		c.category desc
  } 10



  # ----------------------------------------------------
  # whopping query to retreive all classes as above
  # and all the coupons and types defined for each class
  #
  # the comments above apply here also
  # ----------------------------------------------------

  db_store_qry get_category_types_and_coupons {
	select distinct
		c.category,
		c.ev_class_id,
		c.sort as ev_class_sort,
		'T' as type,
		c.name as class_name,
		t.ev_type_id as id,
		t.name       as name,
		t.blurb      as blurb,
		''           as sort,
		x.xl_blurb_1,
		x.xl_blurb_2,
		x.xl_blurb_3,

		c.disporder,
		t.disporder
	from
		tevclass  c,
		tevtype   t,
		outer tblurbxlate x

	where
		c.sort          like ?
		and   c.category      like ?
		and   t.ev_class_id   = c.ev_class_id

		and exists (
			select
				e.ev_id
			from
				tev e,
				tEvUnstl    u
			where
				u.ev_type_id = t.ev_type_id
				and    u.ev_id      = e.ev_id
				and    e.displayed  = t.displayed

				and pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'Y'

				and    e.result_conf   = 'N'

				and    e.channels   like ?
				and    e.fo_avail = 'Y'

				and    exists (
					select
						m.ev_mkt_id
					from
						tEvMkt m
					where
						e.ev_id = m.ev_id
						and    m.displayed = e.displayed
						and    m.channels  like ?
						and    m.fo_avail = 'Y'
				)
		)

		and   x.ref_id = t.ev_type_id
		and   x.sort   = 'TYPE'
		and   x.lang  = ?

		and   c.displayed     = 'Y'
		and   t.displayed     = 'Y'

		and   c.fo_avail = 'Y'
		and   t.fo_avail = 'Y'

		and   c.channels      like ?
		and   t.channels      like ?

	union all

	select distinct
		c.category,
		c.ev_class_id,
		c.sort as ev_class_sort,
		'C' as type,
		c.name as class_name,
		u.coupon_id as id,
		u.desc      as name,
		u.blurb     as blurb,
		u.sort      as sort,
		x.xl_blurb_1,
		x.xl_blurb_2,
		x.xl_blurb_3,
		c.disporder,
		0
	from
		tevclass   c,
		tevtype    t,
		tcoupon    u,
		tcouponmkt cm,
		tev        e,
		tevmkt     m,
		outer tblurbxlate x,
		tEvUnstl    un

	where
		c.sort          like ?
		and   c.category      like ?
		and   un.ev_id        = e.ev_id
		and   t.ev_class_id   = c.ev_class_id
		and   t.ev_type_id    = e.ev_type_id
		and   e.ev_id         = m.ev_id
		and   u.ev_class_id   = c.ev_class_id
		and   u.coupon_id     = cm.coupon_id
		and   cm.ev_mkt_id    = m.ev_mkt_id

		and   x.ref_id        = u.coupon_id
		and   x.sort          = 'COUPON'

		and   c.displayed     = 'Y'
		and   t.displayed     = 'Y'
		and   u.displayed     = 'Y'
		and   cm.displayed    = 'Y'
		and   e.displayed     = 'Y'
		and   m.displayed     = 'Y'

		and   c.fo_avail = 'Y'
		and   t.fo_avail = 'Y'
		and   e.fo_avail = 'Y'
		and   m.fo_avail = 'Y'

		and   c.channels      like ?
		and   t.channels      like ?
		and   e.channels      like ?
		and   m.channels      like ?
		and   u.channels      like ?

		and pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'Y'

		and   e.result_conf   = 'N'
		and   x.lang          = ?
	order by
		13,2,4,14
  } 10


  #
  # similar to above query, but retrieves only for a
  # selected class
  #

  db_store_qry get_class_types_and_coupons {
	select distinct
		c.ev_class_id,
		'T' as type,
		c.name as class_name,
		t.ev_type_id as id,
		t.name       as name,
		t.blurb      as blurb,
		x.xl_blurb_1,
		x.xl_blurb_2,
		x.xl_blurb_3,

		c.disporder,
		t.disporder
	from
		tevclass  c,
		tevtype   t,
		outer tblurbxlate x

	where
		c.ev_class_id   = ?
		and   t.ev_class_id   = c.ev_class_id

		and exists (
			select
				e.ev_id
			from
				tev e,
				tEvUnstl    u
			where
				u.ev_type_id = t.ev_type_id
				and u.ev_id         = e.ev_id
				and    e.displayed  = t.displayed

				and pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'Y'

				and    e.result_conf   = 'N'

				and    e.fo_avail = 'Y'
				and    e.channels      like ?

				and    exists (
					select
						m.ev_mkt_id
					from
						tEvMkt m
					where
						e.ev_id = m.ev_id
						and    m.displayed = e.displayed
						and    m.channels  like ?
						and    m.fo_avail = 'Y'
					)
		)
		and   x.ref_id        = t.ev_type_id
		and   x.sort          = 'TYPE'
		and   x.lang          = ?
		and   c.displayed     = 'Y'
		and   t.displayed     = 'Y'

		and   c.fo_avail = 'Y'
		and   t.fo_avail = 'Y'

		and   c.channels      like ?
		and   t.channels      like ?

	union all

	select distinct
		c.ev_class_id as class_id,
		'C' as type,
		c.name as class_name,
		u.coupon_id as id,
		u.desc      as name,
		u.blurb     as blurb,
		x.xl_blurb_1,
		x.xl_blurb_2,
		x.xl_blurb_3,

		c.disporder,
		0
	from
		tevclass   c,
		tevtype    t,
		tcoupon    u,
		tcouponmkt cm,
		tev        e,
		tevmkt     m,
		outer tblurbxlate x,
		tEvUnstl    un

	where
		c.ev_class_id   = ?
		and   un.ev_id        = e.ev_id
		and   t.ev_class_id   = c.ev_class_id
		and   t.ev_type_id    = e.ev_type_id
		and   e.ev_id         = m.ev_id
		and   u.ev_class_id   = c.ev_class_id
		and   u.coupon_id     = cm.coupon_id
		and   cm.ev_mkt_id    = m.ev_mkt_id

		and   x.ref_id        = u.coupon_id
		and   x.sort          = 'COUPON'

		and   c.displayed     = 'Y'
		and   t.displayed     = 'Y'
		and   u.displayed     = 'Y'
		and   cm.displayed    = 'Y'
		and   e.displayed     = 'Y'
		and   m.displayed     = 'Y'

		and   c.fo_avail = 'Y'
		and   t.fo_avail = 'Y'
		and   e.fo_avail = 'Y'
		and   m.fo_avail = 'Y'

		and   c.channels      like ?
		and   t.channels      like ?
		and   e.channels      like ?
		and   m.channels      like ?
		and   u.channels      like ?

		and   e.result_conf   = 'N'


		and pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'Y'

		and   x.lang          = ?
	order by
		10,1,2,11
  }


  # --------------------------------------------------
  # retrieve all types for a given class
  # --------------------------------------------------


  db_store_qry get_types {
	select distinct
		cat.category,
		c.ev_class_id,
		c.name as class_name,
		t.ev_type_id,
		t.name       as type_name,
		t.blurb      as blurb,
		x.xl_blurb_1,
		x.xl_blurb_2,
		x.xl_blurb_3,

		t.disporder
	from
		tevcategory cat,
		tevclass  c,
		tevtype   t,
		tev       e,
		tevocgrp  g,
		tevmkt    m,
		outer tblurbxlate x,
		tEvUnstl    u

	where
		cat.category = c.category
		and   c.ev_class_id   = ?
		and u.ev_class_id     = c.ev_class_id
		and u.ev_id           = e.ev_id
		and   t.ev_class_id   = c.ev_class_id
		and   t.ev_type_id    = e.ev_type_id
		and   e.ev_id         = m.ev_id
		and   t.ev_type_id    = g.ev_type_id
		and   g.ev_oc_grp_id  = m.ev_oc_grp_id

		and   x.ref_id        = t.ev_type_id
		and   x.sort          = 'TYPE'

		and   c.displayed     = 'Y'
		and   t.displayed     = 'Y'
		and   e.displayed     = 'Y'
		and   m.displayed     = 'Y'

		and   c.fo_avail = 'Y'
		and   t.fo_avail = 'Y'
		and   e.fo_avail = 'Y'
		and   m.fo_avail = 'Y'
		and   g.fo_avail = 'Y'

		and pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'Y'

		and   c.channels      like ?
		and   t.channels      like ?
		and   e.channels      like ?
		and   m.channels      like ?
		and   g.channels      like ?

		and   e.result_conf   = ?
		and   x.lang        = ?
	order by
		t.disporder
  }
		# --------------------------------------------------
		# retrieve current types for a given class
		# --------------------------------------------------


  db_store_qry get_current_types {
	select distinct
		c.ev_class_id,
		c.name as class_name,
		t.ev_type_id,
		t.name       as type_name,
		t.blurb      as blurb,
		x.xl_blurb_1,
		x.xl_blurb_2,
		x.xl_blurb_3,

		t.disporder
	from
		tevclass  c,
		tevtype   t,
		tev       e,
		tevocgrp  g,
		tevmkt    m,
		outer tblurbxlate x,
		tEvUnstl    u

	where
		c.ev_class_id   = ?
		and u.ev_class_id    = c.ev_class_id
		and u.ev_id         = e.ev_id
		and   t.ev_class_id   = c.ev_class_id
		and   t.ev_type_id    = e.ev_type_id
		and   e.ev_id         = m.ev_id
		and   t.ev_type_id    = g.ev_type_id
		and   g.ev_oc_grp_id  = m.ev_oc_grp_id

		and   x.ref_id        = t.ev_type_id
		and   x.sort          = 'TYPE'

		and   c.displayed     = 'Y'
		and   t.displayed     = 'Y'
		and   e.displayed     = 'Y'
		and   m.displayed     = 'Y'

		and   c.fo_avail = 'Y'
		and   t.fo_avail = 'Y'
		and   e.fo_avail = 'Y'
		and   m.fo_avail = 'Y'
		and   g.fo_avail = 'Y'

		and pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'Y'

		and   e.result_conf   = 'N'
		and   x.lang        = ?
	order by
		t.disporder
  }



  # --------------------------------------------------
  # retrieve all coupons for a given class
  # --------------------------------------------------

  db_store_qry get_coupons {
	select distinct
		c.ev_class_id,
		c.name as class_name,
		u.coupon_id as id,
		u.desc      as coupon_name,
		u.blurb     as blurb,
		x.xl_blurb_1,
		x.xl_blurb_2,
		x.xl_blurb_3,

		c.disporder
	from
		tevclass   c,
		tevtype    t,
		tcoupon    u,
		tcouponmkt cm,
		tev        e,
		tevunstl   eu,
		tevmkt     m,
		outer tblurbxlate x

	where
		c.ev_class_id   = ?
		and   t.ev_type_id    = eu.ev_type_id
		and   eu.ev_id        = e.ev_id
		and   t.ev_class_id   = c.ev_class_id
		and   t.ev_type_id    = e.ev_type_id
		and   u.ev_class_id   = c.ev_class_id
		and   e.ev_id         = m.ev_id
		and   e.displayed     = c.displayed
		and   u.coupon_id     = cm.coupon_id
		and   cm.ev_mkt_id    = m.ev_mkt_id

		and   x.ref_id        = u.coupon_id
		and   x.sort          = 'COUPON'

		and   c.displayed     = 'Y'
		and   t.displayed     = 'Y'
		and   u.displayed     = 'Y'
		and   cm.displayed    = 'Y'
		and   e.displayed     = 'Y'
		and   m.displayed     = 'Y'

		and   c.fo_avail = 'Y'
		and   t.fo_avail = 'Y'
		and   e.fo_avail = 'Y'
		and   m.fo_avail = 'Y'

		and   c.channels      like ?
		and   t.channels      like ?
		and   e.channels      like ?
		and   m.channels      like ?
		and   u.channels      like ?

		and   e.result_conf   = ?
		and   x.lang          = ?
	order by
		c.disporder
  } 10

  # ---------------------------------------------------------
  # Retreive a coupon
  # ---------------------------------------------------------

  db_store_qry get_coupon {
	select
		c.ev_class_id,
		c.name as class_name,
		t.ev_type_id,
		t.name as type_name,
		u.coupon_id,
		u.sort,
		u.desc as coupon_name,
		u.blurb as blurb,
		x.xl_blurb_1,
		x.xl_blurb_2,
		x.xl_blurb_3,
		e.ev_id,
		e.desc as event_name,
		e.start_time,
		m.ev_mkt_id,
		g.ev_oc_grp_id,
		m.name as mkt_name,
		m.pl_avail,
		m.lp_avail,
		m.sp_avail,
		m.ew_fac_num,
		m.ew_fac_den,
		m.ew_places,
		m.fc_avail,
		m.tc_avail,
		NVL(o.acc_min, m.acc_min) as acc_min,
		m.acc_max,
		nvl(m.hcap_value,0) as hcap_value,
		nvl(m.tax_rate, nvl(e.tax_rate, t.tax_rate)) as tax_rate,
		o.ev_oc_id,
		o.desc as oc_name,
		o.lp_num,
		o.lp_den,
		o.result,
		o.fb_result,

		decode(c.status||t.status||e.status||m.status||nvl(o.status, 'A'),
		'AAAAA', 'A', 'S') as status,

		case
			when pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'N'
			then 'Y'
			else 'N'
		end as started,

		t.disporder as evt_disporder,
		e.disporder as ev_disporder,
		m.disporder as mkt_disporder,
		o.disporder as oc_disporder,
		o.lp_num/o.lp_den as prc_ord,

		m.sort as mkt_sort,
		m.ew_avail
	from
		tEvClass    c,
		tEvType     t,
		tEv         e,
		tEvMkt      m,
		outer tEvOc o,
		tEvOcGrp    g,
		tCoupon     u,
		tCouponMkt  k,
		outer tblurbxlate x
	where
		t.ev_class_id   = c.ev_class_id
		and   t.ev_type_id    = e.ev_type_id
		and   m.ev_id         = e.ev_id
		and   o.ev_id         = e.ev_id
		and   o.ev_mkt_id     = m.ev_mkt_id
		and   m.ev_oc_grp_id  = g.ev_oc_grp_id
		and   t.ev_type_id    = g.ev_type_id
		and   m.ev_mkt_id     = k.ev_mkt_id
		and   k.coupon_id     = u.coupon_id
		and   u.coupon_id     = ?

		and   x.ref_id        = u.coupon_id
		and   x.sort          = 'COUPON'

		and   c.displayed     = 'Y'
		and   t.displayed     = 'Y'
		and   e.displayed     = 'Y'
		and   m.displayed     = 'Y'
		and   o.displayed     = 'Y'
		and   u.displayed     = 'Y'

		and   c.fo_avail = 'Y'
		and   t.fo_avail = 'Y'
		and   e.fo_avail = 'Y'
		and   m.fo_avail = 'Y'
		and   o.fo_avail = 'Y'
		and   g.fo_avail = 'Y'

		and   c.channels      like ?
		and   t.channels      like ?
		and   e.channels      like ?
		and   m.channels      like ?
		and   g.channels      like ?
		and   o.channels      like ?
		and   u.channels      like ?

		and   e.result_conf   = ?
		and   x.lang          = ?
	order by
		t.disporder,
		e.start_time,
		e.disporder,
		e.ev_id,
		o.disporder,
		prc_ord
  }



  db_store_qry get_coupon_head {
	select
		c.ev_class_id,
		c.name as class_name,
		u.coupon_id,
		u.desc as coupon_name,
		u.blurb as blurb,
		x.xl_blurb_1,
		x.xl_blurb_2,
		x.xl_blurb_3
	from
		tEvClass    c,
		tCoupon     u,
		outer tBlurbXlate x
	where
		u.ev_class_id   = c.ev_class_id
		and   u.coupon_id     = ?

		and   x.ref_id        = u.coupon_id
		and   x.sort          = 'COUPON'

		and   c.displayed     = 'Y'
		and   u.displayed     = 'Y'

		and   c.fo_avail      = 'Y'

		and   x.lang          = ?
  }

  db_store_qry get_coupon_selns {
	select
		t.ev_type_id,
		t.name type_name,
		e.ev_id,
		e.desc as event_name,
		e.start_time,
		m.ev_mkt_id,
		g.ev_oc_grp_id,
		m.name as mkt_name,
		o.ev_oc_id,
		o.desc as oc_name,
		m.lp_avail,
		m.sp_avail,
		o.lp_num,
		o.lp_den,
		o.result,
		o.fb_result,

		e.disporder as ev_disporder,
		m.disporder as mkt_disporder,
		o.disporder as oc_disporder,
		o.lp_num/o.lp_den as prc_ord
	from
		tEvType     t,
		tEv         e,
		tEvMkt      m,
		tEvOc       o,
		tEvOcGrp    g,
		tCoupon     u,
		tCouponMkt  k,
		tEvUnstl    un
	where
		t.ev_type_id    = un.ev_type_id
		and   un.ev_id         = e.ev_id
		and   t.ev_type_id    = g.ev_type_id
		and   m.ev_id         = e.ev_id
		and   o.ev_id         = e.ev_id
		and   o.ev_mkt_id     = m.ev_mkt_id
		and   m.ev_oc_grp_id  = g.ev_oc_grp_id
		and   m.ev_mkt_id     = k.ev_mkt_id
		and   k.coupon_id     = u.coupon_id
		and   u.coupon_id     = ?

		and   t.displayed     = 'Y'
		and   e.displayed     = 'Y'
		and   m.displayed     = 'Y'
		and   o.displayed     = 'Y'
		and   u.displayed     = 'Y'

		and   t.fo_avail = 'Y'
		and   e.fo_avail = 'Y'
		and   m.fo_avail = 'Y'
		and   o.fo_avail = 'Y'
		and   g.fo_avail = 'Y'

		and   t.channels      like ?
		and   e.channels      like ?
		and   m.channels      like ?
		and   g.channels      like ?
		and   o.channels      like ?
		and   u.channels      like ?

		and pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'Y'

		and   e.result_conf   = 'N'
	order by
		e.start_time,
		e.disporder,
		e.ev_id,
		o.disporder,
		prc_ord
  }

	# ---------------------------------------------------------
	# Retrieve the contents of all coupons for a particular event_type
	# ---------------------------------------------------------

  db_store_qry get_coupon_fut_for_event_type {
	select
		c.ev_class_id,
		c.name as class_name,
		t.ev_type_id,
		t.name as type_name,
		u.coupon_id,
		u.desc as coupon_name,
		e.ev_id,
		e.desc as event_name,
		e.start_time,
		e.ext_key as ev_ext_key,
		m.ev_mkt_id,
		g.ev_oc_grp_id,
		m.name as mkt_name,
		m.pl_avail,
		m.lp_avail,
		m.sp_avail,
		m.ew_fac_num,
		m.ew_fac_den,
		m.ew_places,
		m.fc_avail,
		m.tc_avail,
		NVL(o.acc_min, m.acc_min) as acc_min,
		m.acc_max,
		nvl(m.tax_rate, nvl(e.tax_rate, t.tax_rate)) as tax_rate,
		o.ev_oc_id,
		o.desc,
		o.lp_num,
		o.lp_den,
		o.fb_result,
		o.ext_key as oc_ext_key,
		decode(c.status||t.status||e.status||m.status||nvl(o.status, 'A'),
		'AAAAA', 'A', 'S') as status,
		e.disporder as ev_disporder,
		m.disporder as mkt_disporder,
		o.disporder as oc_disporder,
		o.lp_num/o.lp_den as prc_ord
	from
		tEvClass    c,
		tEvType     t,
		tEv         e,
		tEvMkt      m,
		outer tEvOc o,
		tEvOcGrp    g,
		tCoupon     u,
		tCouponMkt  k,
		tEvUnstl    un
	where
		t.ev_class_id   = c.ev_class_id
		and un.ev_id         = e.ev_id
		and   t.ev_type_id    = un.ev_type_id
		and   m.ev_id         = e.ev_id
		and   o.ev_id         = e.ev_id
		and   o.ev_mkt_id     = m.ev_mkt_id
		and   m.ev_oc_grp_id  = g.ev_oc_grp_id
		and   t.ev_type_id    = g.ev_type_id
		and   m.ev_mkt_id     = k.ev_mkt_id
		and   k.coupon_id     = u.coupon_id
		and   t.ev_type_id    = ?
		and   m.sort          = ?


		and   c.displayed     = 'Y'
		and   t.displayed     = 'Y'
		and   e.displayed     = 'Y'
		and   m.displayed     = 'Y'
		and   o.displayed     = 'Y'
		and   u.displayed     = 'Y'

		and   c.fo_avail = 'Y'
		and   t.fo_avail = 'Y'
		and   e.fo_avail = 'Y'
		and   m.fo_avail = 'Y'
		and   o.fo_avail = 'Y'
		and   g.fo_avail = 'Y'

		and   c.channels      like ?
		and   t.channels      like ?
		and   e.channels      like ?
		and   m.channels      like ?
		and   g.channels      like ?
		and   o.channels      like ?
		and   u.channels      like ?

		and   e.result_conf   = 'N'

		and pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'Y'

	order by
		e.start_time,
		e.disporder,
		e.ev_id,
		o.disporder,
		prc_ord
  }



  # --------------------------------------------------------------
  # get all market/selections for a specified event
  # the outer join to tevoc ensures that the SC market is returned
  # --------------------------------------------------------------


  db_store_qry get_mkts_for_ev {
	select
		c.ev_class_id,
		c.name as class_name,
		c.sort as ev_class_sort,

		t.ev_type_id,
		t.name as type_name,
		e.ev_id,
		e.desc as event_name,
		e.sort as ev_sort,
		e.start_time,
		e.ext_key as ev_ext_key,
		m.ev_mkt_id,
		g.ev_oc_grp_id,
		m.name as mkt_name,
		g.blurb,
		x.xl_blurb_1,
		x.xl_blurb_2,
		x.xl_blurb_3,

		m.ew_avail,
		m.pl_avail,
		m.lp_avail,
		m.sp_avail,
		m.ew_fac_num,
		m.ew_fac_den,
		m.ew_places,
		m.fc_avail,
		m.tc_avail,
		NVL(o.acc_min, m.acc_min) as acc_min,
		m.acc_max,
		m.sort as mkt_sort,
		nvl(m.tax_rate, nvl(e.tax_rate, t.tax_rate)) as tax_rate,
		o.ev_oc_id,
		o.desc as oc_name,
		o.lp_num,
		o.lp_den,
		o.sp_num,
		o.sp_den,
		o.result,
			o.fb_result,
		o.ext_key as oc_ext_key,
		decode(c.status||t.status||e.status||m.status||nvl(o.status, 'A'),
		'AAAAA', 'A', 'S') as status,

		case
			when pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'N'
			then 'Y'
			else 'N'
		end as started,

		m.disporder as mkt_disporder,
		o.disporder as oc_disporder,
		o.lp_num/o.lp_den as prc_ord
	from
		tEvClass    c,
		tEvType     t,
		tEv         e,
		tEvMkt      m,
		outer tEvOc o,
		tEvOcGrp    g,
		outer tblurbxlate x

	where
		t.ev_class_id   = c.ev_class_id
		and   t.ev_type_id    = e.ev_type_id
		and   e.ev_id         = ?
		and   m.ev_id         = e.ev_id
		and   o.ev_id         = e.ev_id
		and   o.ev_mkt_id     = m.ev_mkt_id
		and   m.ev_oc_grp_id  = g.ev_oc_grp_id
		and   t.ev_type_id    = g.ev_type_id

		and   x.ref_id        = g.ev_oc_grp_id
		and   x.sort          = 'MARKET'

		and   c.displayed     = 'Y'
		and   t.displayed     = 'Y'
		and   e.displayed     = 'Y'
		and   m.displayed     = 'Y'
		and   o.displayed     = 'Y'

		and c.fo_avail = 'Y'
		and t.fo_avail = 'Y'
		and e.fo_avail = 'Y'
		and m.fo_avail = 'Y'
		and o.fo_avail = 'Y'
		and g.fo_avail = 'Y'

		and   c.channels      like ?
		and   t.channels      like ?
		and   e.channels      like ?
		and   m.channels      like ?
		and   g.channels      like ?
		and   o.channels      like ?

		and   e.result_conf   = ?
		and x.lang       = ?
	order by
		m.disporder,
		m.ev_mkt_id,
		o.disporder,
		prc_ord
  }

	db_store_qry get_mkts_for_ev_without_sc {
	select
		c.ev_class_id,
		c.name as class_name,
		c.sort as ev_class_sort,

		t.ev_type_id,
		t.name as type_name,
		e.ev_id,
		e.desc as event_name,
		e.sort as ev_sort,
		e.start_time,
		e.ext_key as ev_ext_key,
		m.ev_mkt_id,
		g.ev_oc_grp_id,
		m.name as mkt_name,
		g.blurb,
		x.xl_blurb_1,
		x.xl_blurb_2,
		x.xl_blurb_3,

		m.ew_avail,
		m.pl_avail,
		m.lp_avail,
		m.sp_avail,
		m.ew_fac_num,
		m.ew_fac_den,
		m.ew_places,
		m.fc_avail,
		m.tc_avail,
		NVL(o.acc_min, m.acc_min) as acc_min,
		m.acc_max,
		m.sort as mkt_sort,
		nvl(m.tax_rate, nvl(e.tax_rate, t.tax_rate)) as tax_rate,
		o.ev_oc_id,
		o.desc as oc_name,
		o.lp_num,
		o.lp_den,
		o.sp_num,
		o.sp_den,
		o.result,
				o.fb_result,
		o.ext_key as oc_ext_key,
		decode(c.status||t.status||e.status||m.status||nvl(o.status, 'A'),
		'AAAAA', 'A', 'S') as status,

		case
			when pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'N'
			then 'Y'
			else 'N'
		end as started,

		m.disporder as mkt_disporder,
		o.disporder as oc_disporder,
		o.lp_num/o.lp_den as prc_ord
	from
		tEvClass    c,
		tEvType     t,
		tEv         e,
		tEvMkt      m,
		tEvOc       o,
		tEvOcGrp    g,
		outer tblurbxlate x

	where
		t.ev_class_id   = c.ev_class_id
		and   t.ev_type_id    = e.ev_type_id
		and   e.ev_id         = ?
		and   m.ev_id         = e.ev_id
		and   o.ev_id         = e.ev_id
		and   o.ev_mkt_id     = m.ev_mkt_id
		and   m.ev_oc_grp_id  = g.ev_oc_grp_id
		and   t.ev_type_id    = g.ev_type_id

		and   x.ref_id        = g.ev_oc_grp_id
		and   x.sort          = 'MARKET'

		and   c.displayed     = 'Y'
		and   t.displayed     = 'Y'
		and   e.displayed     = 'Y'
		and   m.displayed     = 'Y'
		and   o.displayed     = 'Y'

		and   c.fo_avail = 'Y'
		and   t.fo_avail = 'Y'
		and   e.fo_avail = 'Y'
		and   m.fo_avail = 'Y'
		and   o.fo_avail = 'Y'
		and   g.fo_avail = 'Y'

		and   c.channels      like ?
		and   t.channels      like ?
		and   e.channels      like ?
		and   m.channels      like ?
		and   g.channels      like ?
		and   o.channels      like ?

		and   e.result_conf   = ?
		and x.lang       = ?
	order by
		m.disporder,
		m.ev_mkt_id,
		o.disporder,
		prc_ord
  }

  # --------------------------------------------------------------
  # get all selections for a specified market
  # the outer join to tevoc ensures that the SC market is returned
  # --------------------------------------------------------------


  db_store_qry get_mkt_selns_for_ev {
	select
		c.ev_class_id,
		c.name as class_name,
		c.sort as ev_class_sort,

		t.ev_type_id,
		t.name as type_name,
		e.ev_id,
		e.desc as event_name,
		e.start_time,
		e.ext_key as ev_ext_key,
		m.ev_mkt_id,
		g.ev_oc_grp_id,
		m.name as mkt_name,
		g.blurb,
		x.xl_blurb_1,
		x.xl_blurb_2,
		x.xl_blurb_3,

		m.ew_avail,
		m.pl_avail,
		m.lp_avail,
		m.sp_avail,
		m.ew_fac_num,
		m.ew_fac_den,
		m.ew_places,
		m.fc_avail,
		m.tc_avail,
		NVL(o.acc_min, m.acc_min) as acc_min,
		m.acc_max,
		m.sort as mkt_sort,
		nvl(m.hcap_value,0) as hcap_value,
		nvl(m.tax_rate, nvl(e.tax_rate, t.tax_rate)) as tax_rate,
		o.ev_oc_id,
		o.desc as oc_name,
		o.lp_num,
		o.lp_den,
		o.sp_num,
		o.sp_den,
		o.cs_home,
		o.cs_away,
		o.result,
			o.fb_result,
		o.ext_key as oc_ext_key,
		decode(c.status||t.status||e.status||m.status||nvl(o.status, 'A'),
		'AAAAA', 'A', 'S') as status,

		case
			when pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'N'
			then 'Y'
			else 'N'
		end as started,

		m.disporder as mkt_disporder,
		o.disporder as oc_disporder,
		o.lp_num/o.lp_den as prc_ord
	from
		tEvClass    c,
		tEvType     t,
		tEv         e,
		tEvMkt      m,
		outer tEvOc o,
		tEvOcGrp    g,
		outer tblurbxlate x

	where
		t.ev_class_id   = c.ev_class_id
		and   t.ev_type_id    = e.ev_type_id
		and   m.ev_mkt_id     = ?
		and   m.ev_id         = e.ev_id
		and   o.ev_id         = e.ev_id
		and   o.ev_mkt_id     = m.ev_mkt_id
		and   m.ev_oc_grp_id  = g.ev_oc_grp_id
		and   t.ev_type_id    = g.ev_type_id

		and   x.ref_id        = g.ev_oc_grp_id
		and   x.sort          = 'MARKET'

		and   c.displayed     = 'Y'
		and   t.displayed     = 'Y'
		and   e.displayed     = 'Y'
		and   m.displayed     = 'Y'
		and   o.displayed     = 'Y'

		and c.fo_avail = 'Y'
		and t.fo_avail = 'Y'
		and e.fo_avail = 'Y'
		and m.fo_avail = 'Y'
		and o.fo_avail = 'Y'
		and g.fo_avail = 'Y'

		and   c.channels      like ?
		and   t.channels      like ?
		and   e.channels      like ?
		and   m.channels      like ?
		and   g.channels      like ?
		and   o.channels      like ?

		and   e.result_conf   = ?
		and x.lang       = ?
	order by
		m.disporder,
		m.ev_mkt_id,
		o.disporder,
		prc_ord,
		oc_name
  }

  # ------------------------------------------------
  # get all selections in the specified market
  # in all events that have an active market
  # of type ev_oc_grp_id
  # ------------------------------------------------

  db_store_qry get_events_for_oc_grp {
	select
		c.ev_class_id,
		c.name as class_name,
		t.ev_type_id,
		t.name as type_name,
		g.ev_oc_grp_id,
		m.name as mkt_name,
		g.blurb,
		e.ev_id,
		e.desc as event_name,
		e.start_time,
		e.ext_key as ev_ext_key,
		e.sort as ev_sort,
		m.ev_mkt_id,
		m.sort as mkt_sort,
		m.pl_avail,
		m.lp_avail,
		m.sp_avail,
		m.ew_fac_num,
		m.ew_fac_den,
		m.ew_places,
			m.ew_avail,
		m.fc_avail,
		m.tc_avail,
		NVL(o.acc_min, m.acc_min) as acc_min,
		m.acc_max,
		nvl(m.tax_rate, nvl(e.tax_rate, t.tax_rate)) as tax_rate,
		o.ev_oc_id,
		o.desc as oc_name,
		o.lp_num,
		o.lp_den,
		o.result,
		o.ext_key as oc_ext_key,

		decode(c.status||t.status||e.status||m.status||nvl(o.status, 'A'),
		'AAAAA', 'A', 'S') as status,

		case
			when pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'N'
			then 'Y'
			else 'N'
		end as started,

		e.disporder as ev_disporder,
		o.disporder as oc_disporder,
		o.lp_num/o.lp_den as prc_ord
	from
		tEvClass    c,
		tEvType     t,
		tEv         e,
		tEvMkt      m,
		outer tEvOc o,
		tEvOcGrp    g
	where
		t.ev_class_id   = c.ev_class_id
		and   t.ev_type_id    = e.ev_type_id
		and   m.ev_id         = e.ev_id
		and   o.ev_id         = e.ev_id
		and   o.ev_mkt_id     = m.ev_mkt_id
		and   g.ev_oc_grp_id  = ?
		and   m.ev_oc_grp_id  = g.ev_oc_grp_id
		and   t.ev_type_id    = g.ev_type_id

		and   c.displayed     = 'Y'
		and   t.displayed     = 'Y'
		and   e.displayed     = 'Y'
		and   m.displayed     = 'Y'
		and   o.displayed     = 'Y'

		and   c.fo_avail = 'Y'
		and   t.fo_avail = 'Y'
		and   e.fo_avail = 'Y'
		and   m.fo_avail = 'Y'
		and   o.fo_avail = 'Y'
		and   g.fo_avail = 'Y'

		and   c.channels      like ?
		and   t.channels      like ?
		and   e.channels      like ?
		and   m.channels      like ?
		and   g.channels      like ?
		and   o.channels      like ?

		and   e.result_conf   = ?

	order by
		e.start_time,
		e.disporder,
		e.ev_id,
		o.disporder,
		prc_ord
  }

  # ------------------------------------------------
  # get all events for a given type
  # ------------------------------------------------

  db_store_qry get_events_for_type {
	select distinct
		c.ev_class_id,
		c.name as class_name,
		t.ev_type_id,
		t.name as type_name,
		e.ev_id,
		e.desc as event_name,
		e.start_time,
		e.venue,
		e.country,
		e.ext_key as ev_ext_key,

		case
			when pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'N'
			then 'Y'
			else 'N'
		end as started,

		decode(c.status||t.status||e.status,
		'AAA', 'A', 'S') as status,

		e.disporder as ev_disporder
	from
		tEvClass    c,
		tEvType     t,
		tEv         e,
		tEvUnstl    un
	where
		t.ev_class_id   = c.ev_class_id
		and   t.ev_type_id    = un.ev_type_id
		and   t.ev_type_id    = ?
		and un.ev_id         = e.ev_id

		and   exists (
				select *
				from
					tEvMkt im,
					tEvOcGrp ig
				where
					im.ev_id = e.ev_id
					and im.ev_oc_grp_id = ig.ev_oc_grp_id
					and im.status = 'A' and im.channels like ?
					and ig.channels like ?

					and im.displayed = 'Y'
					and im.fo_avail = 'Y'
					and ig.fo_avail = 'Y'
		)

		and   c.displayed     = 'Y'
		and   t.displayed     = 'Y'
		and   e.displayed     = 'Y'

		and   c.fo_avail = 'Y'
		and   t.fo_avail = 'Y'
		and   e.fo_avail = 'Y'

		and   c.channels      like ?
		and   t.channels      like ?
		and   e.channels      like ?

		and   e.result_conf   = ?

		and pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'Y'


	order by
		e.start_time,
		e.disporder,
		e.desc
		}


  # ------------------------------------------------
  # get all events for a given type and date
  # ------------------------------------------------

  db_store_qry get_events_for_type_btwn_dates {
	select
		c.ev_class_id,
		c.name as class_name,
		t.ev_type_id,
		t.name as type_name,
		e.ev_id,
		e.desc as event_name,
		e.start_time,
		e.ext_key as ev_ext_key,

		case
			when pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'N'
			then 'Y'
			else 'N'
		end as started,

		decode(c.status||t.status||e.status,
		'AAA', 'A', 'S') as status,

		e.disporder as ev_disporder
	from
		tEvClass    c,
		tEvType     t,
		tEv         e
	where
		t.ev_class_id   = c.ev_class_id
		and   t.ev_type_id    = e.ev_type_id
		and   t.ev_type_id    = ?
		and   t.ev_type_id    = e.ev_type_id

		and   c.displayed     = 'Y'
		and   t.displayed     = 'Y'
		and   e.displayed     = 'Y'

		and   c.fo_avail = 'Y'
		and   t.fo_avail = 'Y'
		and   e.fo_avail = 'Y'

		and   c.channels      like ?
		and   t.channels      like ?
		and   e.channels      like ?

		and   e.start_time    >= ?
		and   e.start_time    <= ?

		and   e.result_conf   =  ?


	order by
		e.start_time,
		e.disporder
  }


  # ---------------------------------------------------
  # get a list of available markets for a given type
  # ---------------------------------------------------

  db_store_qry get_mkt_list_for_type {
	select distinct
		c.ev_class_id,
		c.name as class_name,
		t.ev_type_id,
		t.name as type_name,
		m.ev_mkt_id,
		g.ev_oc_grp_id,
		m.name as mkt_name,
		g.sort,

		decode(c.status||t.status||e.status||m.status,
		'AAAA', 'A', 'S') as status,

		case
			when pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'N'
			then 'Y'
			else 'N'
		end as started,

		g.disporder
	from
		tEvClass    c,
		tEvType     t,
		tEv         e,
		tEvMkt      m,
		tEvOcGrp    g
	where
		t.ev_class_id   = c.ev_class_id
		and   t.ev_type_id    = ?
		and   t.ev_type_id    = e.ev_type_id
		and   m.ev_id         = e.ev_id
		and   m.ev_oc_grp_id  = g.ev_oc_grp_id
		and   t.ev_type_id    = g.ev_type_id

		and   c.displayed     = 'Y'
		and   t.displayed     = 'Y'
		and   e.displayed     = 'Y'
		and   m.displayed     = 'Y'

		and c.fo_avail = 'Y'
		and t.fo_avail = 'Y'
		and e.fo_avail = 'Y'
		and m.fo_avail = 'Y'
		and g.fo_avail = 'Y'

		and   c.channels      like ?
		and   t.channels      like ?
		and   e.channels      like ?
		and   m.channels      like ?
		and   g.channels      like ?

		and   e.result_conf   = ?

	order by
		g.disporder
  }


  # ---------------------------------------------------
  # get a list of available markets for a given event (useful for market drop downs)
  # ---------------------------------------------------

  db_store_qry get_mkt_list_for_event {
	select distinct
		c.ev_class_id,
		c.name as class_name,
		t.ev_type_id,
		t.name as type_name,
		m.ev_mkt_id,
		m.ew_avail,
		m.pl_avail,
		m.ew_fac_num,
		m.ew_fac_den,
		m.ew_places,
		g.ev_oc_grp_id,
		m.name as mkt_name,

		decode(c.status||t.status||e.status||m.status,
		'AAAA', 'A', 'S') as status,

		case
			when pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'N'
			then 'Y'
			else 'N'
		end as started,

		g.disporder

	from
		tEvClass    c,
		tEvType     t,
		tEv         e,
		tEvMkt      m,
		tEvOcGrp    g
	where
		t.ev_class_id   = c.ev_class_id
		and   t.ev_type_id    = e.ev_type_id
		and   e.ev_id         = ?
		and   m.ev_id         = e.ev_id
		and   m.ev_oc_grp_id  = g.ev_oc_grp_id
		and   t.ev_type_id    = g.ev_type_id

		and   c.displayed     = 'Y'
		and   t.displayed     = 'Y'
		and   e.displayed     = 'Y'
		and   m.displayed     = 'Y'

		and c.fo_avail = 'Y'
		and t.fo_avail = 'Y'
		and e.fo_avail = 'Y'
		and m.fo_avail = 'Y'
		and g.fo_avail = 'Y'

		and   c.channels      like ?
		and   t.channels      like ?
		and   e.channels      like ?
		and   m.channels      like ?
		and   g.channels      like ?

		and   e.result_conf   = ?
	order by
		g.disporder
  }

  # ---------------------------------------------------
  # get a list of available markets for a given event, with blurbs
   # (v. similar to above)
  # ---------------------------------------------------

  db_store_qry get_mkt_list_for_event_with_blurbs {
	select distinct
		c.ev_class_id,
		c.name as class_name,
		t.ev_type_id,
		t.name as type_name,
		m.ev_mkt_id,
		g.ev_oc_grp_id,
		m.name as mkt_name,

		decode(c.status||t.status||e.status||m.status,
		'AAAA', 'A', 'S') as status,

		case
			when pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'N'
			then 'Y'
			else 'N'
		end as started,

		g.disporder,
		g.blurb,
		x.xl_blurb_1,
		x.xl_blurb_2,
		x.xl_blurb_3

	from
		tEvClass    c,
		tEvType     t,
		tEv         e,
		tEvMkt      m,
		tEvOcGrp    g,
		outer tblurbxlate x
	where
		t.ev_class_id   = c.ev_class_id
		and   t.ev_type_id    = e.ev_type_id
		and   e.ev_id         = ?
		and   m.ev_id         = e.ev_id
		and   m.ev_oc_grp_id  = g.ev_oc_grp_id
		and   t.ev_type_id    = g.ev_type_id

		and   c.displayed     = 'Y'
		and   t.displayed     = 'Y'
		and   e.displayed     = 'Y'
		and   m.displayed     = 'Y'

		and c.fo_avail = 'Y'
		and t.fo_avail = 'Y'
		and e.fo_avail = 'Y'
		and m.fo_avail = 'Y'
		and g.fo_avail = 'Y'

		and   c.channels      like ?
		and   t.channels      like ?
		and   e.channels      like ?
		and   m.channels      like ?
		and   g.channels      like ?

		and   x.ref_id        = g.ev_oc_grp_id
		and   x.sort          = 'MARKET'
		and   x.lang          = ?
		and   e.result_conf   = ?
	order by
		g.disporder
  }

  # ---------------------------------------------------
  # get a list of events and their corresponding
  # markets for a given type
  # ---------------------------------------------------

  db_store_qry get_event_mkt_list_for_type {
	select
		c.ev_class_id,
		c.name as class_name,
		t.ev_type_id,
		t.name as type_name,
		e.ev_id,
		e.desc as event_name,
		e.ext_key as ev_ext_key,
		m.ev_mkt_id,
		g.ev_oc_grp_id,
		m.name as mkt_name,

		decode(c.status||t.status||e.status||m.status,
		'AAAA', 'A', 'S') as status,

		case
			when pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'N'
			then 'Y'
			else 'N'
		end as started,

		e.disporder,
		g.disporder
	from
		tEvClass    c,
		tEvType     t,
		tEv         e,
		tEvMkt      m,
		tEvOcGrp    g
	where
		t.ev_class_id   = c.ev_class_id
		and   t.ev_type_id    = ?
		and   t.ev_type_id    = e.ev_type_id
		and   m.ev_id         = e.ev_id
		and   m.ev_oc_grp_id  = g.ev_oc_grp_id
		and   t.ev_type_id    = g.ev_type_id

		and   c.displayed     = 'Y'
		and   t.displayed     = 'Y'
		and   e.displayed     = 'Y'
		and   m.displayed     = 'Y'

		and c.fo_avail = 'Y'
		and t.fo_avail = 'Y'
		and e.fo_avail = 'Y'
		and m.fo_avail = 'Y'
		and g.fo_avail = 'Y'

		and   c.channels      like ?
		and   t.channels      like ?
		and   e.channels      like ?
		and   m.channels      like ?
		and   g.channels      like ?

		and   e.result_conf   = ?

	order by
		e.disporder,
		e.ev_id,
		g.disporder
  }


   # get selections list for a given mkt_id
   # used mainly for test purposes - be careful about
   # using in live sites
   db_store_qry get_selns_for_mkt {
	select
		o.ev_oc_id,
		o.desc as oc_name,
		o.lp_num,
		o.lp_den,
		o.sp_num,
		o.sp_den,
		o.result,
		o.fb_result,
		o.ext_key as oc_ext_key,
		o.status,
		o.disporder as oc_disporder,
		lp_num/lp_den as prc_ord,
		sp_avail,
		lp_avail,
		pm_avail,
		m.ev_id
	from
		tEvOc o,
		tevmkt m
	where
		o.ev_mkt_id = ?
		and    o.ev_mkt_id = m.ev_mkt_id
		and    m.channels  like ?
		and    o.channels  like ?
				and    o.displayed = 'Y'
		and    m.fo_avail = 'Y'
		and    o.fo_avail = 'Y'
	order by
		o.disporder, prc_ord
  }


  # Idea is to use a correlated subquery
  # so we don't have to fetch all the way down
  # the hierarchy.
  # (n.b. this DOES work for scorecast markets)
  #
  # Cached for 5 minutes
  db_store_qry get_all_active_types {
	select
		c.ev_class_id,
		c.name as class_name,
		t.ev_type_id,
		t.name       as type_name,
		c.disporder as class_disporder,
		t.disporder as type_disporder
	from
		tevclass  c,
		tevtype   t
	where
		c.displayed     = 'Y'
		and   t.displayed     = 'Y'
		and   c.fo_avail = 'Y'
		and   t.fo_avail = 'Y'

		and   c.ev_class_id = t.ev_class_id
		and exists (
			select
				o.ev_oc_id
			from
				tev       e,
				tevmkt    m,
				tevoc     o,
				tEvUnstl    un
			where
				un.ev_type_id=t.ev_type_id
				and un.ev_id         = e.ev_id
				and m.ev_id = e.ev_id
				and o.ev_mkt_id = m.ev_mkt_id

				and e.displayed     = 'Y'
				and m.displayed     = 'Y'
				and o.displayed     = 'Y'

				and e.fo_avail = 'Y'
				and m.fo_avail = 'Y'
				and o.fo_avail = 'Y'

				and e.status='A'
				and m.status='A'
				and o.status='A'

				and pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'Y'

				and e.result_conf   = 'N'
		)
	order by
		c.disporder, c.name, t.disporder, t.name
  } 300
}


proc handle_err args {
  err_add $args
  return
}

proc get_current {} {


  if [catch {set rs [db_exec_qry get_current_date]} msg] {
	handle_err "get_current" {} "failed to get current date: $msg"
	return
  }

  set ret ""
  if {[db_get_nrows $rs] > 0} {
	set ret [db_get_coln $rs 0]
  }

  db_close $rs

  return $ret
}


##
#  Returns a result set containing all classes meeting
#  the passed parameters
#
#  The result set should be closed after use
##

proc ob_get_classes {{class_sort "%"} {category "%"} {period "FUTURE"} {channel "I"}} {

  global LANG

  if {$period == "FUTURE"} {
	set result    N
  } elseif {$period == "PAST"} {
	set result    Y
  } elseif {$period == "ALL"} {
	set result    %
  }

  set channel "%$channel%"

  if [catch {set rs [db_exec_qry get_classes \
		   $class_sort\
		   $category\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $LANG]} msg] {
	return [handle_err "ob_get_classes" {$class_sort $category $period $LANG $channel} \
		"error retreiving classes: $msg"]
  }

  return $rs
}



proc ob_get_classes_and_types {{class_sort "%"} {category "%"} {period "FUTURE"} {channel "I"}} {
  global LANG


  if {$period == "FUTURE"} {
	set result    N
  } elseif {$period == "PAST"} {
	set result    Y
  } elseif {$period == "ALL"} {
	set result    %
  }

  set channel "%$channel%"

  if [catch {set rs [db_exec_qry get_category_types_and_coupons\
		   $class_sort\
		   $category\
		   $channel\
		   $channel\
		   $LANG \
		   $channel\
		   $channel\
		   $class_sort\
		   $category\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $LANG]} msg] {
	return [handle_err "ob_get_classes_and_types" {$class_sort $category $period $channel} \
	  "error retreiving classes: $msg" ]
  }

  return $rs
}

proc ob_get_types_and_coupons {class {period "FUTURE"} {channel "I"}} {

  global LANG

  if {$period == "FUTURE"} {
	set result    N
  } elseif {$period == "PAST"} {
	set result    Y
  } elseif {$period == "ALL"} {
	set result    %
  }

  set channel "%$channel%"

  if [catch {set rs [db_exec_qry get_class_types_and_coupons\
		   $class\
		   $channel\
		   $channel\
		   $LANG\
		   $channel\
		   $channel\
		   $class\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $LANG]} msg] {
	return [handle_err "ob_get_types_and_coupons" {$class $period $channel} \
	  "error retreiving types etc.: $msg" ]
  }

  return $rs
}



proc ob_get_types {class {period "FUTURE"} {channel "I"}} {
  global LANG

  if {$period == "FUTURE"} {
	set result    N
  } elseif {$period == "PAST"} {
	set result    Y
  } elseif {$period == "ALL"} {
	set result    %
  }

  set channel "%$channel%"

  if [catch {set rs [db_exec_qry get_types\
		   $class\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $result\
		   $LANG]} msg] {
	return [handle_err "ob_get_types" {$class $period $channel} \
		"error retrieving types: $msg"]

  }

  return $rs

}

proc ob_get_current_types {class} {
  global LANG

  if [catch {set rs [db_exec_qry get_current_types\
		  $class\
		  $LANG]} msg] {
	return [handle_err "ob_get_current_types" {$class} \
		"error retrieving types: $msg"]
  }

  return $rs
}


proc ob_get_coupons {class {period "FUTURE"} {channel "I"}} {

  global LANG

  if {$period == "FUTURE"} {
	set result    N
  } elseif {$period == "PAST"} {
	set result    Y
  } elseif {$period == "ALL"} {
	set result    %
  }

  set channel "%$channel%"

  if [catch {set rs [db_exec_qry get_coupons\
		   $class\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $result\
		   $LANG]} msg] {
	return [handle_err "ob_get_types" {$class $period $channel} \
		"error retreiving types: $msg"]

  }

  return $rs

}

proc ob_get_coupon {coupon {period "FUTURE"} {channel "I"}} {

  global LANG

  switch -- $period {
	"FUTURE" {
	  set result N
	}
	"PAST" {
	  set result Y
	}
	"ALL" {
	  set result %
	}
	default {
	  error "invalid period ($period) passed to ob_get_coupon"
	}

  }

  set channel "%$channel%"

  if [catch {set rs [db_exec_qry get_coupon \
		   $coupon\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $result\
		   $LANG]} msg] {

	return [handle_err "ob_get_coupon"\
		{$coupon $period $channel} \
		"error retreiving coupon: $msg"]

  }

  return $rs
}

proc ob_get_coupon_head {coupon} {

  global LANG


  if [catch {set rs [db_exec_qry get_coupon_head \
		   $coupon\
		   $LANG]} msg] {

	return [handle_err "ob_get_coupon_head"\
		{$coupon} \
		"error retreiving coupon: $msg"]

  }

  return $rs
}

proc ob_get_coupon_selns {coupon {channel "I"}} {

  set channel "%$channel%"

  if [catch {set rs [db_exec_qry get_coupon_selns \
							     $coupon\
							     $channel\
							     $channel\
							     $channel\
							     $channel\
							     $channel\
							     $channel]} msg] {

	return [handle_err "ob_get_coupon_selns"\
		{$coupon $channel} \
		"error retreiving coupon: $msg"]

  }

  return $rs
}


#
# The contents of all coupons in a particular event_type having a particular
# maket_sort.
#
proc ob_get_coupon_for_event_type {ev_type_id {mkt_sort "MR"} {period "FUTURE"} {channel "I"}} {

  switch -- $period {
	"FUTURE" {
	  set qry get_coupon_fut_for_event_type
	}
	default {
	  set qry get_coupon_fut_for_event_type
	}
  }

  set channel "%$channel%"

  if [catch {set rs [db_exec_qry $qry $ev_type_id \
							     $mkt_sort\
							     $channel\
							     $channel\
							     $channel\
							     $channel\
							     $channel\
							     $channel\
							     $channel]} msg] {
	return [handle_err "ob_lwd_get_coupon"\
	  {$ev_type_id $mkt_sort $period $channel} \
	  "error retreiving coupon: $msg"]

  }

  return $rs
}


proc ob_get_mkts_for_ev {event {period "FUTURE"} {channel "I"}} {
  global LANG


  switch -- $period {
	"FUTURE" {
	  set result N
	}
	"PAST" {
	  set result Y
	}
	"ALL" {
	  set result %
	}
	default {
	  error "invalid period ($period)"
	}
  }

  set channel "%$channel%"

  if [catch {set rs [db_exec_qry get_mkts_for_ev \
		   $event\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $result $LANG]} msg] {

	return [handle_err "ob_get_mkt_selns_for_ev" {$class $period $channel} \
		"error retreiving markets: $msg"]

  }

  return $rs
}

proc ob_get_mkts_for_ev_without_sc {event {period "FUTURE"} {channel "I"}} {

  global LANG

  switch -- $period {
	"FUTURE" {
	  set result N
	}
	"PAST" {
	  set result Y
	}
	"ALL" {
	  set result %
	}
	default {
	  error "invalid period ($period)"
	}
  }

  set channel "%$channel%"

  if [catch {set rs [db_exec_qry get_mkts_for_ev_without_sc \
		   $event\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $result $LANG]} msg] {

	return [handle_err "ob_get_mkt_selns_for_ev" {$class $period $channel} \
		"error retreiving markets: $msg"]

  }

  return $rs
}


proc ob_get_mkt_selns_for_ev {mkt {period "FUTURE"} {channel "I"}} {

  global LANG

  switch -- $period {
	"FUTURE" {
	  set result N
	}
	"PAST" {
	  set result Y
	}
	"ALL" {
	  set result %
	}
	default {
	  error "invalid period ($period)"
	}
  }

  set channel "%$channel%"

  if [catch {set rs [db_exec_qry get_mkt_selns_for_ev \
		   $mkt\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $result $LANG]} msg] {

	return [handle_err "ob_get_mkt_selns_for_ev" {$mkt $period $channel} \
		"error retreiving markets: $msg"]

  }

  return $rs
}


proc ob_get_events_for_oc_grp {mkt {period "FUTURE"} {channel "I"}} {



  switch -- $period {
	"FUTURE" {
	  set result N
	}
	"PAST" {
	  set result Y
	}
	"ALL" {
	  set result %
	}
	default {
	  error "invalid period ($period)"
	}
  }

  set channel "%$channel%"

  if [catch {set rs [db_exec_qry get_events_for_oc_grp\
		   $mkt\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $result]} msg] {

	return [handle_err "ob_get_events_for_oc_grp" \
		{$mkt $period $channel} \
		"error retreiving events: $msg"]

  }

  return $rs
}


proc ob_get_event_list_for_type {type {period "FUTURE"} {channel "I"}} {

  switch -- $period {
	"FUTURE" {
	  set result N
	}
	"PAST" {
	  set result Y
	}
	"ALL" {
	  set result %
	}
	default {
	  error "invalid period ($period)"
	}
  }

  set channel "%$channel%"

  if [catch {set rs [db_exec_qry get_events_for_type\
		   $type\
		   $channel\
	   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $result]} msg] {

	return [handle_err "ob_get_events" \
		{$type $period $channel} \
		"error retreiving events: $msg"]

  }

  return $rs
}


proc ob_get_event_list_for_type_btwn_dates {type date {period "FUTURE"} {channel "I"}} {

  switch -- $period {
	"FUTURE" {
	  set result N
	}
	"PAST" {
	  set result Y
	}
	"ALL" {
	  set result %
	}
	default {
	  error "invalid period ($period)"
	}
  }

  set channel "%$channel%"

  # Set up informix start and end dates
  scan $date      "%4s-%2s-%2s" Y m d
  set  start      "$Y-$m-$d 00:00:00"
  set  end        "$Y-$m-$d 23:59:59"

  if [catch {set rs [db_exec_qry get_events_for_type_btwn_dates\
		   $type\
		   $channel\
		   $channel\
		   $channel\
		   $start\
		   $end\
		   $result]} msg] {

	return [handle_err "ob_get_events" \
		{$type $start $end $period} \
		"error retreiving events: $msg"]

  }

  return $rs
}

proc ob_get_mkt_list_for_type {type {period "FUTURE"} {channel "I"}} {



  switch -- $period {
	"FUTURE" {
	  set result N
	}
	"PAST" {
	  set result Y
	}
	"ALL" {
	  set result %
	}
	default {
	  error "invalid period ($period)"
	}
  }

  set channel "%$channel%"

  if [catch {set rs [db_exec_qry get_mkt_list_for_type \
		   $type\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $result]} msg] {

	return [handle_err "ob_get_mkt_list_for_type"\
		{$type $period $channel} \
		"error retreiving markets: $msg"]

  }

  return $rs
}

proc ob_get_mkt_list_for_ev {event {period "FUTURE"} {channel "I"}} {



  switch -- $period {
	"FUTURE" {
	  set result N
	}
	"PAST" {
	  set result Y
	}
	"ALL" {
	  set result %
	}
	default {
	  error "invalid period ($period)"
	}
  }

  set channel "%$channel%"


  if [catch {set rs [db_exec_qry get_mkt_list_for_event\
		   $event\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $result]} msg] {

	return [handle_err "ob_get_mkt_list_for_event"\
		{$event $period $channel} \
		"error retreiving markets: $msg"]

  }

  return $rs
}

proc ob_get_mkt_list_for_ev_with_blurbs {event {period "FUTURE"} {channel "I"}} {

  global LANG

  switch -- $period {
	"FUTURE" {
	  set result N
	}
	"PAST" {
	  set result Y
	}
	"ALL" {
	  set result %
	}
	default {
	  error "invalid period ($period)"
	}
  }

  set channel "%$channel%"

  if [catch {set rs [db_exec_qry get_mkt_list_for_event_with_blurbs\
		   $event\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $LANG\
		   $result]} msg] {

	return [handle_err "ob_get_mkt_list_for_event"\
		{$event $period $channel} \
		"error retreiving markets: $msg"]

  }

  return $rs
}

proc ob_get_ev_mkt_list_for_type {type {period "FUTURE"} {channel "I"}} {

  switch -- $period {
	"FUTURE" {
	  set result N
	}
	"PAST" {
	  set result Y
	}
	"ALL" {
	  set result %
	}
	default {
	  error "invalid period ($period)"
	}
  }

  set channel "%$channel%"

  if [catch {set rs [db_exec_qry get_event_mkt_list_for_type\
		   $type\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $channel\
		   $result]} msg] {

	return [handle_err "ob_get_mkt_list_for_type" {$type $period $channel} \
		"error retreiving markets: $msg"]

  }

  return $rs
}

proc ob_get_selns_for_mkt {mkt {channel "I"}} {
   # used mainly for test purposes - be careful about
   # using in live sites

  set channel "%$channel%"

  if [catch {set rs [db_exec_qry get_selns_for_mkt $mkt $channel $channel]} msg] {
	return [handle_err "ob_get_selns_for_mkt" {$mkt $channel} "error retreiving selections: $msg"]
  }
  return $rs
}

proc ob_get_all_active_types {} {

	if [catch {set rs [db_exec_qry get_all_active_types]} msg] {

  return [handle_err "ob_get_all_active_types" {} \
		"error retreiving markets: $msg"]

	}

	return $rs

}
