# ==============================================================
# $Id: bf_cat.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::BETFAIR_CAT {

#
# ----------------------------------------------------------------------------
# Go to category list- binding betfair categories
# ----------------------------------------------------------------------------
#
proc bind_bf_category_list args {

	global DB BF_MTCH CAT

	ob::log::write INFO {bind_bf_category_list - Binding Betfair Categories}

	set sql [subst {
			select
				bf_type_id,
				name
			from
				tBFEventType
		}]

	set stmt   [inf_prep_sql $::DB $sql]
	set res_bf [inf_exec_stmt $stmt]
	inf_close_stmt $stmt	
	
	set BF_MTCH(nrows) [db_get_nrows $res_bf]
	set ob_id_list [list]
	
	for {set r 0 } {$r < $BF_MTCH(nrows)} {incr r} {
		set BF_MTCH($r,bf_id)  	[db_get_col $res_bf $r bf_type_id]
		set BF_MTCH($r,bf_desc) [db_get_col $res_bf $r name]
	}	
	
	db_close $res_bf
		
	tpBindVar BFEvItemsId  BF_MTCH 		bf_id     bf_mtch_idx
	tpBindVar BFDesc       BF_MTCH 		bf_desc   bf_mtch_idx
	tpSetVar  BFNumCats    $BF_MTCH(nrows)
}



#
# ----------------------------------------------------------------------------
# Update List of BetFair Categories
# ----------------------------------------------------------------------------
#
proc go_category_bf_refresh args {

	global DB USERNAME BF_EV_TYPES

	#
	# Login to BetFair and get the active event types
	#
	if { [BETFAIR::SESSION::create_session "GLB"] == -1 } {
		set msg "Error creating Session. Try again later"
		ob::log::write ERROR {go_category_bf_refresh - $msg}
		err_bind "$msg"
		ADMIN::CATEGORY::go_category_list
		return
	}

	BETFAIR::INT::get_active_event_types

	if {[info exists BF_EV_TYPES(num_ev_types)]} {

		set bf_cat_cnt $BF_EV_TYPES(num_ev_types)

		if {$bf_cat_cnt > 0} {
			set sql {
				execute procedure pBFInsEvItem (
						p_adminuser = ?,
						p_status    = ?,
						p_bf_type   = ?,
						p_bf_id     = ?,
						p_bf_desc   = ?
				)
			}

			set sql1 {
				execute procedure pBFInsEvType (
						p_ext_type_id  = ?,
						p_name	       = ?,
						p_next_mkt_id  = ?,
						p_bf_exch_id   = ?,
						p_bf_ev_items_id = ?
				)
			}

			set stmt [inf_prep_sql $DB $sql]
			set stmt1 [inf_prep_sql $DB $sql1]

			for {set i 0} {$i < $bf_cat_cnt} {incr i} {
				if {[catch {set rs [inf_exec_stmt $stmt $USERNAME "A" "ET" $BF_EV_TYPES($i,id) $BF_EV_TYPES($i,name)]} msg]} {
					ob::log::write ERROR {go_category_bf_refresh - $msg}
				} else {
					set bf_ev_items_id [db_get_coln $rs 0 0]
	
					#
					# Insert the type to the tBFEventType
					#
					if {[catch {inf_exec_stmt $stmt1 	$BF_EV_TYPES($i,id)\
											$BF_EV_TYPES($i,name)\
											$BF_EV_TYPES($i,next_mkt_id)\
											$BF_EV_TYPES($i,exch_id)\
					$bf_ev_items_id} msg]} {
						ob::log::write ERROR {go_category_bf_refresh - $msg}
					}
				}
			}

			inf_close_stmt $stmt
			inf_close_stmt $stmt1
		}
	}

	ADMIN::CATEGORY::go_category_list
}

}
