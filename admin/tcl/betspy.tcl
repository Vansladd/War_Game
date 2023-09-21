# ==============================================================
# $Id: betspy.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::BETSPY {

	asSetAct ADMIN::BETSPY::GoBetspy            [namespace code go_betspy]
	asSetAct ADMIN::BETSPY::go_betspy_dd        [namespace code go_betspy_classes]
	asSetAct ADMIN::BETSPY::go_betspy_types     [namespace code go_betspy_types]
	asSetAct ADMIN::BETSPY::go_betspy_events  [namespace code go_betspy_events]
	asSetAct ADMIN::BETSPY::go_betspy_markets [namespace code go_betspy_markets]
	asSetAct ADMIN::BETSPY::DoBetspyParams      [namespace code do_betspy_params]
	asSetAct ADMIN::BETSPY::update_mkts_events  [namespace code update_mkts_events]
	asSetAct ADMIN::BETSPY::DoBetspyMktsEvents  [namespace code do_betspy_mkts_events]

	proc go_betspy args {

		global EVENTS MKTS

		catch {unset EVENTS}
		catch {unset MKTS}

		global DB

		set show_betspy          0
		set show_kiosk           0
		set period_min           0
		set period_max           0
		set max_stake_all        0
		set min_stake_all        0
		set max_stake_horses     0
		set min_stake_horses     0
		set max_stake_greyhounds 0
		set min_stake_greyhounds 0
		set max_stake_football   0
		set min_stake_football   0


		# Queries
		set betspy_kiosk_sql {
			select
				param_value
			from
				tbetspyparam
			where
				param_name = ?
		}

		set betspy_events_sql {
			select
				'E' type,
				bp.param_value id,
				ev.desc name,
				t.name t_name
			from
				tbetspyparam bp,
				tev ev,
				tevtype t
			where
				bp.param_value = ev.ev_id and
				ev.ev_type_id = t.ev_type_id and
				bp.param_name = 'EVENT_NA'
		}

		set betspy_mkts_sql {
			select
				'M' type,
				bp.param_value id,
				e.desc ev_name,
				g.name name
			from
				tbetspyparam bp,
				tevmkt mk,
				tev e,
				tevocgrp g
			where
				bp.param_value = mk.ev_mkt_id and
				mk.ev_oc_grp_id = g.ev_oc_grp_id and
				mk.ev_id = e.ev_id and
				bp.param_name = 'MKT_NA'
		}

		# BETSPY STATUS
		set stmt [inf_prep_sql $DB $betspy_kiosk_sql]
		set rs  [inf_exec_stmt $stmt "BETSPY_STATUS"]
		inf_close_stmt $stmt

		if {[db_get_nrows $rs] == 1} {
			set show_betspy [db_get_col $rs 0 param_value]
		} else {
			ob::log::write ERROR "There is more than one value for BETSPY_STATUS in tbetspyparam: Defaulting to showing it."
			set show_betspy 1
		}
		db_close $rs

		# KIOSK STATUS
		set stmt [inf_prep_sql $DB $betspy_kiosk_sql]
		set rs  [inf_exec_stmt $stmt "KIOSK_STATUS"]
		inf_close_stmt $stmt

		if {$show_betspy == 1} {
			if {[db_get_nrows $rs] == 1} {
				set show_kiosk [db_get_col $rs 0 param_value]
			} else {
				ob::log::write ERROR "There is more than one value for KIOSK_STATUS in tbetspyparam: Defaulting to showing it."
				set show_kiosk 1
			}
			db_close $rs
		}

		# MINIMUM PERIOD
		set stmt [inf_prep_sql $DB $betspy_kiosk_sql]
		set rs  [inf_exec_stmt $stmt "PERIOD_MIN"]
		inf_close_stmt $stmt

		if {[db_get_nrows $rs] == 1} {
			set period_min [db_get_col $rs 0 param_value]
		} else {
			ob::log::write ERROR "There is more than one value for PERIOD_MIN in tbetspyparam: Defaulting to 1"
			set period_min 1
		}
		db_close $rs

		# MAXIMUM PERIOD
		set stmt [inf_prep_sql $DB $betspy_kiosk_sql]
		set rs  [inf_exec_stmt $stmt "PERIOD_MAX"]
		inf_close_stmt $stmt

		if {[db_get_nrows $rs] == 1} {
			set period_max [db_get_col $rs 0 param_value]
		} else {
			ob::log::write ERROR "There is more than one value for PERIOD_MIN in tbetspyparam: Defaulting to 5"
			set period_max 5
		}
		db_close $rs

		if {$show_betspy} {
			tpBindString SHOW_BETSPY "checked"
		}
		if {$show_kiosk} {
			tpBindString SHOW_KIOSK "checked"
		}

		tpBindString PERIOD_MIN $period_min
		tpBindString PERIOD_MAX $period_max

		# STAKES ALL
		set stmt [inf_prep_sql $DB $betspy_kiosk_sql]
		set rs  [inf_exec_stmt $stmt "ALL_STAKE_MIN"]
		inf_close_stmt $stmt

		if {[db_get_nrows $rs] == 1} {
			set min_stake_all [db_get_col $rs 0 param_value]
		} else {
			ob::log::write ERROR "There is more than one value for ALL_STAKE_MIN in tbetspyparam: Defaulting to 1"
			set min_stake_all 1
		}
		db_close $rs

		set stmt [inf_prep_sql $DB $betspy_kiosk_sql]
		set rs  [inf_exec_stmt $stmt "ALL_STAKE_MAX"]
		inf_close_stmt $stmt

		if {[db_get_nrows $rs] == 1} {
			set max_stake_all [db_get_col $rs 0 param_value]
		} else {
			ob::log::write ERROR "There is more than one value for ALL_STAKE_MAX in tbetspyparam: Defaulting to 500"
			set max_stake_all 500
		}
		db_close $rs

		tpBindString MIN_STAKE_ALL $min_stake_all
		tpBindString MAX_STAKE_ALL $max_stake_all

		# STAKES HORSES
		set stmt [inf_prep_sql $DB $betspy_kiosk_sql]
		set rs  [inf_exec_stmt $stmt "HRSE_STAKE_MIN"]
		inf_close_stmt $stmt

		if {[db_get_nrows $rs] == 1} {
			set min_stake_horses [db_get_col $rs 0 param_value]
		} else {
			ob::log::write ERROR "There is more than one value for HRSE_STAKE_MIN in tbetspyparam: Defaulting to 1"
			set min_stake_horses 1
		}
		db_close $rs

		set stmt [inf_prep_sql $DB $betspy_kiosk_sql]
		set rs  [inf_exec_stmt $stmt "HRSE_STAKE_MAX"]
		inf_close_stmt $stmt

		if {[db_get_nrows $rs] == 1} {
			set max_stake_horses [db_get_col $rs 0 param_value]
		} else {
			ob::log::write ERROR "There is more than one value for HRSE_STAKE_MAX in tbetspyparam: Defaulting to 500"
			set max_stake_horses 500
		}
		db_close $rs

		tpBindString MIN_STAKE_HORSES $min_stake_horses
		tpBindString MAX_STAKE_HORSES $max_stake_horses

		# STAKES GREYHOUNDS
		set stmt [inf_prep_sql $DB $betspy_kiosk_sql]
		set rs  [inf_exec_stmt $stmt "DOG_STAKE_MIN"]
		inf_close_stmt $stmt

		if {[db_get_nrows $rs] == 1} {
			set min_stake_greyhounds [db_get_col $rs 0 param_value]
		} else {
			ob::log::write ERROR "There is more than one value for DOG_STAKE_MIN in tbetspyparam: Defaulting to 1"
			set min_stake_greyhounds 1
		}
		db_close $rs

		set stmt [inf_prep_sql $DB $betspy_kiosk_sql]
		set rs  [inf_exec_stmt $stmt "DOG_STAKE_MAX"]
		inf_close_stmt $stmt

		if {[db_get_nrows $rs] == 1} {
			set max_stake_greyhounds [db_get_col $rs 0 param_value]
		} else {
			ob::log::write ERROR "There is more than one value for DOG_STAKE_MAX in tbetspyparam: Defaulting to 500"
			set max_stake_greyhounds 500
		}
		db_close $rs

		tpBindString MIN_STAKE_GREYHOUNDS $min_stake_greyhounds
		tpBindString MAX_STAKE_GREYHOUNDS $max_stake_greyhounds

		# STAKES FOOTBALL
		set stmt [inf_prep_sql $DB $betspy_kiosk_sql]
		set rs  [inf_exec_stmt $stmt "FBALL_STAKE_MIN"]
		inf_close_stmt $stmt

		if {[db_get_nrows $rs] == 1} {
			set min_stake_football [db_get_col $rs 0 param_value]
		} else {
			ob::log::write ERROR "There is more than one value for FBALL_STAKE_MIN in tbetspyparam: Defaulting to 1"
			set min_stake_football 1
		}
		db_close $rs

		set stmt [inf_prep_sql $DB $betspy_kiosk_sql]
		set rs  [inf_exec_stmt $stmt "FBALL_STAKE_MAX"]
		inf_close_stmt $stmt

		if {[db_get_nrows $rs] == 1} {
			set max_stake_football [db_get_col $rs 0 param_value]
		} else {
			ob::log::write ERROR "There is more than one value for FBALL_STAKE_MAX in tbetspyparam: Defaulting to 500"
			set max_stake_football 500
		}
		db_close $rs

		tpBindString MIN_STAKE_FOOTBALL $min_stake_football
		tpBindString MAX_STAKE_FOOTBALL $max_stake_football

		# EVENTS
		set stmt [inf_prep_sql $DB $betspy_events_sql]
		set rs  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set n_events [db_get_nrows $rs]
		if {$n_events} {
			for {set i 0} {$i < $n_events} {incr i} {
				set EVENTS($i,ev_id)  [db_get_col $rs $i id]
				set EVENTS($i,name)   [db_get_col $rs $i name]
				set EVENTS($i,t_name) [db_get_col $rs $i t_name]
			}
			set EVENTS(num) $n_events
		} else {
			set EVENTS(num) 0
		}
		tpSetVar NUM_EVENTS $EVENTS(num)
		db_close $rs

		# MARKETS
		set stmt [inf_prep_sql $DB $betspy_mkts_sql]
		set rs  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set n_mkts [db_get_nrows $rs]
		if {$n_mkts} {
			for {set i 0} {$i < $n_mkts} {incr i} {
				set MKTS($i,ev_mkt_id) [db_get_col $rs $i id]
				set MKTS($i,name)      [db_get_col $rs $i name]
				set MKTS($i,ev_name)   [db_get_col $rs $i ev_name]
			}
			set MKTS(num) $n_mkts
		} else {
			set MKTS(num) 0
		}
		tpSetVar NUM_MKTS $MKTS(num)
		db_close $rs

		tpBindVar	EV_ID		EVENTS	ev_id	ev_idx
		tpBindVar	EV_NAME		EVENTS	name	ev_idx
		tpBindVar	EV_T_NAME	EVENTS	t_name	ev_idx

		tpBindVar	MKT_ID		MKTS	ev_mkt_id	mkt_idx
		tpBindVar	MKT_NAME	MKTS	name		mkt_idx
		tpBindVar   MKT_EV_NAME MKTS    ev_name     mkt_idx

		asPlayFile -nocache betspy.html
	}

	proc do_betspy_params args {

		global DB

		set betspy_update_sql {
			update
				tbetspyparam
			set
				param_value = ?
			where
				param_name = ?
		}

		if {[reqGetArg betspy] == 1} {
			set betspy_checkbox 1
		} else {
			set betspy_checkbox 0
		}

		if {[reqGetArg kiosk] == 1} {
			set kiosk_checkbox 1
		} else {
			set kiosk_checkbox 0
		}
		set min_p           [reqGetArg period_min]
		set max_p           [reqGetArg period_max]
		set max_all         [reqGetArg max_stake_all]
		set min_all         [reqGetArg min_stake_all]
		set max_horses      [reqGetArg max_stake_horses]
		set min_horses      [reqGetArg min_stake_horses]
		set max_dogs        [reqGetArg max_stake_greyhounds]
		set min_dogs        [reqGetArg min_stake_greyhounds]
		set max_fball       [reqGetArg max_stake_football]
		set min_fball       [reqGetArg min_stake_football]

		set stmt [inf_prep_sql $DB $betspy_update_sql]
		set rs  [inf_exec_stmt $stmt $betspy_checkbox "BETSPY_STATUS"]
		set rs  [inf_exec_stmt $stmt $kiosk_checkbox "KIOSK_STATUS"]
		set rs  [inf_exec_stmt $stmt $min_p "PERIOD_MIN"]
		set rs  [inf_exec_stmt $stmt $max_p "PERIOD_MAX"]
		set rs  [inf_exec_stmt $stmt $max_all "ALL_STAKE_MAX"]
		set rs  [inf_exec_stmt $stmt $min_all "ALL_STAKE_MIN"]
		set rs  [inf_exec_stmt $stmt $min_horses "HRSE_STAKE_MIN"]
		set rs  [inf_exec_stmt $stmt $max_horses "HRSE_STAKE_MAX"]
		set rs  [inf_exec_stmt $stmt $max_dogs "DOG_STAKE_MAX"]
		set rs  [inf_exec_stmt $stmt $min_dogs "DOG_STAKE_MIN"]
		set rs  [inf_exec_stmt $stmt $min_fball "FBALL_STAKE_MIN"]
		set rs  [inf_exec_stmt $stmt $max_fball "FBALL_STAKE_MAX"]
		inf_close_stmt $stmt

		db_close $rs

		go_betspy
	}

	proc do_betspy_mkts_events args {

		global DB

		set betspy_delete_sql {
			delete from
				tbetspyparam
			where
				param_name = ? and
				param_value = ?
		}

		set stmt [inf_prep_sql $DB $betspy_delete_sql]

		set market_ids [reqGetArgs markets]
		set event_ids  [reqGetArgs events]

		for {set i 0} {$i < [llength $market_ids]} {incr i} {
			set rs  [inf_exec_stmt $stmt "MKT_NA" [lindex $market_ids $i]]
		}

		for {set i 0} {$i < [llength $event_ids]} {incr i} {
			set rs  [inf_exec_stmt $stmt "EVENT_NA" [lindex $event_ids $i]]
		}

		inf_close_stmt $stmt

		go_betspy
	}

	proc update_mkts_events args {

		global DB

		set betspy_insert_sql {
			execute procedure pUpdBetspyParams(
				p_param_name = ?,
				p_param_value = ?
			)
		}

		set stmt [inf_prep_sql $DB $betspy_insert_sql]

		set market_ids  [reqGetArgs markets]
		set event_ids   [reqGetArgs events]

		for {set i 0} {$i < [llength $market_ids]} {incr i} {
			set rs  [inf_exec_stmt $stmt "MKT_NA" [lindex $market_ids $i]]
		}

		for {set i 0} {$i < [llength $event_ids]} {incr i} {
			set rs  [inf_exec_stmt $stmt "EVENT_NA" [lindex $event_ids $i]]
		}

		inf_close_stmt $stmt

		go_betspy
	}



	###############
	# DRILL DROWN #
	###############
	#
	# Generate class list
	#
	proc go_betspy_classes {} {

		global DB

		set sql {
			select
				c.ev_class_id,
				c.name as class_name,
				c.disporder
			from
				tEvClass c
			where
				c.name = '|Horse Racing|' OR
				c.name = '|Greyhounds|' OR
				c.name = '|Football|'
			order by
				c.disporder
		}

		set stmt [inf_prep_sql $DB [subst $sql]]
		set rs   [inf_exec_stmt $stmt]

		inf_close_stmt $stmt

		tpSetVar dd_rows [db_get_nrows $rs]

		tpSetVar show_link 1
		tpSetVar no_select 1

		tpBindTcl id   "sb_res_data $rs dd_idx ev_class_id"
		tpBindTcl key  "sb_res_data $rs dd_idx ev_class_id"
		tpBindTcl name "sb_res_data $rs dd_idx class_name"

		tpBindString level   CLASS
		tpSetVar     level   CLASS
		tpBindString title   Classes
		tpBindString link_action ADMIN::BETSPY::go_betspy_types

		asPlayFile -nocache betspy_dd.html

		db_close $rs
	}

	#
	# show types
	#
	proc go_betspy_types {} {

		global DB

		set sql {
			select distinct
				'T' as type,
				'T' || t.ev_type_id as key,
				t.ev_type_id as id,
				t.name       as name,
				t.disporder
			from
				tevclass  c,
				tevtype   t,
				tev       e
			where
				c.ev_class_id   = ?
				and c.ev_class_id   = t.ev_class_id
				and t.ev_type_id    = e.ev_type_id
				and e.start_time    > current - interval(7) day to day
				and e.result_conf   = 'N'
		}

		set class [reqGetArg id]
		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt $class]

		inf_close_stmt $stmt

		tpSetVar dd_rows [db_get_nrows $rs]
		tpSetVar no_select 1

		tpBindTcl id     "sb_res_data $rs dd_idx id"
		tpBindTcl key    "sb_res_data $rs dd_idx key"
		tpBindTcl name   "sb_res_data $rs dd_idx name"
		tpBindTcl level  "ADMIN::BESTBETS::print_level $rs dd_idx type"

		tpBindString link_action ADMIN::BETSPY::go_betspy_events

		tpBindString title "Types"

		asPlayFile -nocache betspy_dd.html

		db_close $rs
	}

	#
	# show Events
	#
	proc go_betspy_events {} {

		global DB

		set sql {
			select
				e.ev_id,
				e.desc as event_name,
				e.start_time,
				e.disporder as ev_disporder
			from
				tEvClass    c,
				tEvType     t,
				tEv         e
			where
				t.ev_class_id   = c.ev_class_id
				and t.ev_type_id    = e.ev_type_id
				and t.ev_type_id    = ?
				and t.ev_type_id    = e.ev_type_id
				and e.start_time    > current - interval(7) day to day
				and e.result_conf   = 'N'
			order by
				e.start_time,
				e.disporder
		}

		set type [reqGetArg id]
		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt $type]

		inf_close_stmt $stmt

		tpSetVar dd_rows [db_get_nrows $rs]
		tpSetVar show_link 1
		tpBindTcl id   "sb_res_data $rs dd_idx ev_id"
		tpBindTcl key  "sb_res_data $rs dd_idx ev_id"
		tpBindTcl name "sb_res_data $rs dd_idx event_name"

		tpBindString level   EVENT
		tpBindString title   Events
		tpBindString link_action ADMIN::BETSPY::go_betspy_markets

		tpSetVar TYPE E

		asPlayFile -nocache betspy_dd.html

		db_close $rs
	}

	#
	# show Markets
	#
	proc go_betspy_markets {} {

		global DB

		set sql {
			select distinct
				m.ev_mkt_id,
				g.name as mkt_name,
				g.disporder
			from
				tEvClass    c,
				tEvType     t,
				tEv         e,
				tEvMkt      m,
				tEvOcGrp    g
			where
				t.ev_class_id   = c.ev_class_id
				and t.ev_type_id    = e.ev_type_id
				and e.ev_id         = ?
				and m.ev_id         = e.ev_id
				and m.ev_oc_grp_id  = g.ev_oc_grp_id
				and t.ev_type_id    = g.ev_type_id
				and e.start_time    > current - interval(7) day to day
				and e.result_conf   = 'N'
			order by
				g.disporder
		}

		set event [reqGetArg id]
		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt $event]

		inf_close_stmt $stmt


		tpSetVar dd_rows [db_get_nrows $rs]
		tpSetVar show_link 0
		tpBindTcl id   "sb_res_data $rs dd_idx ev_mkt_id"
		tpBindTcl name "sb_res_data $rs dd_idx mkt_name"

		tpBindString level   MARKET
		tpBindString title   Markets

		tpSetVar TYPE M

		asPlayFile -nocache betspy_dd.html

		db_close $rs
	}

}
