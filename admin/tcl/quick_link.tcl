# ==============================================================
# $Id: quick_link.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2009 Orbis Technology Ltd. All rights reserved.
# ==============================================================

# This file was thrown together because i was sick and tired of going through
#  loads of slow admin pages just to edit a market / outcome etc.
#
# All fairly self explanatory. Select a level, enter an id. Job done.
#
# Expands on the existing Ev Id Search

namespace eval ADMIN::QUICK_LINK {

	asSetAct ADMIN::QUICK_LINK::GoQuickLink      [namespace code go_quick_link]
	asSetAct ADMIN::QUICK_LINK::DoQuickLink      [namespace code do_quick_link]

}



proc ADMIN::QUICK_LINK::go_quick_link args {

	set level [reqGetArg level]
	set id    [reqGetArg id]

	asPlayFile quick_link.html


}



#
# Call the correct admin procedure with the correct arguements
#
proc ADMIN::QUICK_LINK::do_quick_link args {

	ob_log::write INFO {ADMIN::QUICK_LINK::do_quick_link}

	global DB

	set level [reqGetArg level]
	set id    [reqGetArg id]

	if {$level == ""} {
		go_quick_link
		return
	}

	set test_ok 0

	set test_ok [test_level $level $id]

	if {!$test_ok} {
		tpSetVar ERR 1
		tpBindString ERR_MSG "Invalid id for this level"
		tpBindString LEVEL $level
		tpBindString ID    $id
		ADMIN::EV_SEL::go_ev_sel
		return
	}

	switch -- $level {
		"Coupon" {
			reqSetArg CouponId $id
			ADMIN::COUPON::go_coupon
		}
		"Category" {

			# This call needs a category name id
			set sql {
				select
					category
				from
					tEvCategory
				where
					ev_category_id = ?
			}

			set stmt [inf_prep_sql $DB $sql]
			set rs   [inf_exec_stmt $stmt $id]
			inf_close_stmt $stmt

			reqSetArg Category [db_get_col $rs 0 category]

			ADMIN::CATEGORY::go_category
		}
		"Class" {
			reqSetArg ClassId $id
			ADMIN::CLASS::go_class
		}
		"EvType" {

			# This call needs a class id
			set sql {
				select
					ev_class_id
				from
					tEvType
				where
					ev_type_id = ?
			}

			set stmt [inf_prep_sql $DB $sql]
			set rs   [inf_exec_stmt $stmt $id]
			inf_close_stmt $stmt

			reqSetArg ClassId [db_get_col $rs 0 ev_class_id]
			reqSetArg TypeId $id
			ADMIN::TYPE::go_type
		}
		"MktType" {
			
			# This call needs a class id
			set sql {
				select
					c.ev_class_id,
					t.ev_type_id
				from
					tEvOcGrp o,
					tEvType t,
					tEvClass c
				where
					c.ev_class_id = t.ev_class_id and
					t.ev_type_id = o.ev_type_id and
					o.ev_oc_grp_id = ?
			}

			set stmt [inf_prep_sql $DB $sql]
			set rs   [inf_exec_stmt $stmt $id]
			inf_close_stmt $stmt

			reqSetArg ClassId [db_get_col $rs 0 ev_class_id]
			reqSetArg TypeId  [db_get_col $rs 0 ev_type_id]
			reqSetArg MktGrpId $id

			ADMIN::MKT_GRP::go_mkt_grp
		}
		"Event" {
			reqSetArg EvId $id
			ADMIN::EVENT::go_ev
		}
		"Market" {
			reqSetArg MktId $id
			ADMIN::MARKET::go_mkt
		}
		"Outcome" {
			reqSetArg OcId $id
			ADMIN::SELN::go_oc
		}
		default {
			ADMIN::EV_SEL::go_ev_sel
		}
	}

	return

}



#
# Check that the level / id combination is valid.
#
proc ADMIN::QUICK_LINK::test_level {level id} {

	ob_log::write INFO {ADMIN::QUICK_LINK::test_level level = $level , id = $id}

	global DB

	switch -- $level {
		"Coupon" {
			set table tCoupon
			set field coupon_id
		}
		"Category" {
			set table tEvCategory
			set field ev_category_id
		}
		"Class" {
			set table tEvClass
			set field ev_class_id
		}
		"EvType" {
			set table tEvType
			set field ev_type_id
		}
		"MktType" {
			set table tEvOcGrp
			set field ev_oc_grp_id
		}
		"Event" {
			set table tEv
			set field ev_id
		}
		"Market" {
			set table tEvMkt
			set field ev_mkt_id
		}
		"Outcome" {
			set table tEvOc
			set field ev_oc_id
		}
		default {
			return 0
		}
	}

	set sql [subst {
		select
			*
		from
			$table
		where
			$field = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $id]
	inf_close_stmt $stmt

	if {[db_get_nrows $rs] != 1} {
		return 0
	}

	return 1

}
