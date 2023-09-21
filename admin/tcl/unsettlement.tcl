# ==============================================================
# $Id: unsettlement.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2003 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::UNSTL {

asSetAct ADMIN::UNSTL::ReDirect              [namespace code redirect]
asSetAct ADMIN::UNSTL::ShowUnsettleDateRange [namespace code show_unsettle_date_range]
asSetAct ADMIN::UNSTL::ShowUnsettleCategory  [namespace code show_unsettle_category]
asSetAct ADMIN::UNSTL::ShowUnsettleClass     [namespace code show_unsettle_class]
asSetAct ADMIN::UNSTL::ShowUnsettleType      [namespace code show_unsettle_type]
asSetAct ADMIN::UNSTL::ShowUnsettleEvent     [namespace code show_unsettle_event]
asSetAct ADMIN::UNSTL::ShowUnsettleMarket    [namespace code show_unsettle_market]
asSetAct ADMIN::UNSTL::ShowUnsettleSelection [namespace code show_unsettle_selection]
asSetAct ADMIN::UNSTL::CheckUnsettle         [namespace code check_unsettle]
asSetAct ADMIN::UNSTL::DoUnsettle            [namespace code do_unsettle]
asSetAct ADMIN::UNSTL::ShowUnsettleNegAccts  [namespace code show_unsettle_neg_accts]
asSetAct ADMIN::UNSTL::ShowUnsettleAdjAccts  [namespace code show_unsettle_adj_accts]

variable unstl_log_file

# ----------------------------------------------------------------------------
# redirect - used to handle navigation when form submit buttons are used
# rather than conventional links. In this case the SubmitName parameter is
# used to determine which page to load.
# ----------------------------------------------------------------------------

proc redirect args {

	set act [reqGetArg SubmitName]

	switch $act {
		"ShowUnsettleDateRange" { show_unsettle_date_range }
		"ShowUnsettleCategory"  { show_unsettle_category   }
		"ShowUnsettleClass"     { show_unsettle_class      }
		"ShowUnsettleType"      { show_unsettle_type       }
		"ShowUnsettleEvent"     { show_unsettle_event      }
		"ShowUnsettleMarket"    { show_unsettle_market     }
		"ShowUnsettleSelection" { show_unsettle_selection  }
		"CheckUnsettle"         { check_unsettle           }
		"DoUnsettle"            { do_unsettle              }
	}
}


# ----------------------------------------------------------------------------
# show_unsettle_date_range - first creen from the unsettlement menu. User must
# choose a date range which will be used
# as a filter on the event start time.
# ----------------------------------------------------------------------------

proc show_unsettle_date_range args {

	tpSetVar PlayScreen      "ShowUnsettleDateRange"

	global USERID USERNAME

	if {![op_allowed UnSettle]} {
		tpBindString Message "You don't have permission to un-settle markets"
			tpSetVar Status -1
	} else {
		tpSetVar Status  0
	}

	asPlayFile unsettlement.html
}

# ----------------------------------------------------------------------------
# Select a catagory
# ----------------------------------------------------------------------------
proc show_unsettle_category args {

		tpSetVar PlayScreen      "ShowUnsettleCategory"

		global USERID DB

		set in_date_lo   [reqGetArg date_lo]
		set in_date_hi   [reqGetArg date_hi]
		set in_date_sel  [reqGetArg date_range]

		debug_log_params "ShowUnsettleCategory"

		set valid_y_m_d_for {[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]}

		# Set default min and max dates.

		set d_lo "'0001-01-01 00:00:00'"
		set d_hi "'9999-12-31 23:59:59'"

		if {$in_date_lo != "" || $in_date_hi != ""} {

				# User specified a date range.

				if {$in_date_lo != ""} {

						if {![regexp {^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$} $in_date_lo]} {
							error "Sorry, date \"$in_date_lo\" does not match \"YYYY-MM-DD\" format"
						}
						set d_lo "'$in_date_lo 00:00:00'"
				}
				if {$in_date_hi != ""} {
						set d_hi "'$in_date_hi 23:59:59'"
						if {![regexp {^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$} $in_date_hi]} {
							error "Sorry, date \"$in_date_hi\" does not match \"YYYY-MM-DD\" format"
						}
				}
		} elseif {$in_date_sel != "-"} {

				# User choose a drop down menu option.

				set dt [clock format [clock seconds] -format "%Y-%m-%d"]

				foreach {y m d} [split $dt -] {
						set y [string trimleft $y 0]
						set m [string trimleft $m 0]
						set d [string trimleft $d 0]
				}

				# Handle each menu option by calculating min and max dates
				# relative to the current date...

				if {$in_date_sel == "-6"} {
						set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
						if {[incr d -7] <= 0} {
								if {[incr m -1] < 1} {
										set m 12
										incr y -1
								}
								set d [expr {[days_in_month $m $y]+$d}]
						}
						set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
				} elseif {$in_date_sel == "-3"} {
						set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
						if {[incr d -4] <= 0} {
								if {[incr m -1] < 1} {
										set m 12
										incr y -1
								}
								set d [expr {[days_in_month $m $y]+$d}]
						}
						set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
				} elseif {$in_date_sel == "-2"} {
						set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
						if {[incr d -3] <= 0} {
								if {[incr m -1] < 1} {
										set m 12
										incr y -1
								}
								set d [expr {[days_in_month $m $y]+$d}]
						}
						set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
				} elseif {$in_date_sel == "-1"} {
						if {[incr d -1] <= 0} {
								if {[incr m -1] < 1} {
										set m 12
										incr y -1
								}
								set d [expr {[days_in_month $m $y]+$d}]
						}
						set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
						set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
				} elseif {$in_date_sel == "0"} {
						set d_lo "'$dt 00:00:00'"
						set d_hi "'$dt 23:59:59'"
				}
		}

		# Bind date range variables

		tpBindString DateLoLink  $d_lo
		tpBindString DateHiLink  $d_hi
		tpBindString DateSelLink $in_date_sel

		tpBindString Username $USERID

		set sql "select
						category,
						disporder
				 from
						tevcategory
				 order by disporder asc"

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set rows [db_get_nrows $res]

		tpSetVar NumCategories $rows
		tpBindTcl CategoryName sb_res_data $res class_idx category

		asPlayFile unsettlement.html

		db_close $res
}


# ----------------------------------------------------------------------------
# Select a Class
# ----------------------------------------------------------------------------
proc show_unsettle_class args {

		tpSetVar PlayScreen      "ShowUnsettleClass"

		global DB

		set in_ev_category [reqGetArg category]
		set in_date_lo     [reqGetArg date_lo]
		set in_date_hi     [reqGetArg date_hi]
		set in_date_sel    [reqGetArg date_sel]

		tpBindString  CategoryLink  $in_ev_category
		tpBindString  DateLoLink    $in_date_lo
		tpBindString  DateHiLink    $in_date_hi
		tpBindString  DateSelLink   $in_date_sel

		debug_log_params "ShowUnsettleClass"

		set where_clause "where category = \"$in_ev_category\""

		#
		# Depending on the type of admin user only show Slot or MJC channels
		#
		switch [tpGetVar ADMIN_USER_TYPE] {
				S {
						append where_clause "and (channels like '%I%' or channels like '%P%' or channels like '%H%')"
				}
				M {
						append where_clause "and (channels like '%M%')"
				}
				default {
						append where_clause {}
				}
		}

		set sql "select
						ev_class_id,
						name,
						category,
						languages
				 from
						tEvClass
				 $where_clause
				 order by category, name asc"

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set rows [db_get_nrows $res]

		tpSetVar NumClasses $rows

		tpBindTcl ClassId   sb_res_data $res class_idx ev_class_id
		tpBindTcl ClassName sb_res_data $res class_idx name
		tpBindTcl Languages sb_res_data $res class_idx languages

		asPlayFile unsettlement.html

		db_close $res

}

# ----------------------------------------------------------------------------
# Select a Type
# ----------------------------------------------------------------------------
proc show_unsettle_type args {

		tpSetVar PlayScreen      "ShowUnsettleType"

		global DB

		set in_ev_category    [reqGetArg category]
		set in_ev_class_id    [reqGetArg class_id]
		set in_ev_class_name  [reqGetArg class_name]
		set in_date_lo        [reqGetArg date_lo]
		set in_date_hi        [reqGetArg date_hi]
		set in_date_sel       [reqGetArg date_sel]

		tpBindString  CategoryLink  $in_ev_category
		tpBindString  ClassIdLink   $in_ev_class_id
		tpBindString  ClassNameLink $in_ev_class_name
		tpBindString  DateLoLink    $in_date_lo
		tpBindString  DateHiLink    $in_date_hi
		tpBindString  DateSelLink   $in_date_sel

		debug_log_params "ShowUnsettleType"

		set where_clause "where ev_class_id = $in_ev_class_id"

		set sql "
				select
						ev_type_id,
						name
				from
						tevtype
				$where_clause
				order by name asc"

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set rows [db_get_nrows $res]

		tpSetVar NumTypes $rows

		tpBindTcl TypeId   sb_res_data $res class_idx ev_type_id
		tpBindTcl TypeName sb_res_data $res class_idx name

		asPlayFile unsettlement.html

		db_close $res
}

# ----------------------------------------------------------------------------
# Select a specific event by description and start time.
# ----------------------------------------------------------------------------
proc show_unsettle_event args {

		tpSetVar PlayScreen     "ShowUnsettleEvent"

		global DB

		set in_ev_category    [reqGetArg category]
		set in_ev_class_id    [reqGetArg class_id]
		set in_ev_class_name  [reqGetArg class_name]
		set in_ev_type_id     [reqGetArg type_id]
		set in_ev_type_name   [reqGetArg type_name]
		set in_date_lo        [reqGetArg date_lo]
		set in_date_hi        [reqGetArg date_hi]
		set in_date_sel       [reqGetArg date_sel]

		tpBindString  CategoryLink  $in_ev_category
		tpBindString  ClassIdLink   $in_ev_class_id
		tpBindString  ClassNameLink $in_ev_class_name
		tpBindString  TypeIdLink    $in_ev_type_id
		tpBindString  TypeNameLink  $in_ev_type_name
		tpBindString  DateLoLink    $in_date_lo
		tpBindString  DateHiLink    $in_date_hi
		tpBindString  DateSelLink   $in_date_sel

		debug_log_params "ShowUnsettleEvent"

		# Apply the date range criteria set by the user on the first screen (in
		# the procedure show_unsettle_date_range) to the events.

		set where_clause "where ev_type_id = $in_ev_type_id"
		append where_clause  "and start_time between $in_date_lo and $in_date_hi"

		set sql "
				select
						ev_id,
						desc,
						start_time
				from
						tev
				$where_clause
				order by desc asc"

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set rows [db_get_nrows $res]

		tpSetVar NumEvents $rows

		tpBindTcl EventId   sb_res_data $res class_idx ev_id
		tpBindTcl EventDesc sb_res_data $res class_idx desc
		tpBindTcl StartTime sb_res_data $res class_idx start_time

		asPlayFile unsettlement.html

		db_close $res
}

# ----------------------------------------------------------------------------
# Select market.
# ----------------------------------------------------------------------------
proc show_unsettle_market args {

		log_debug "IN show_unsettle_market"

		tpSetVar PlayScreen    "ShowUnsettleMarket"

		global DB MARKETARRAY

		set in_ev_category   [reqGetArg category]
		set in_ev_class_id   [reqGetArg class_id]
		set in_ev_class_name [reqGetArg class_name]
		set in_ev_type_id    [reqGetArg type_id]
		set in_ev_type_name  [reqGetArg type_name]
		set in_ev_id         [reqGetArg event_id]
		set in_ev_name       [reqGetArg event_name]
		set in_start_time    [reqGetArg start_time]
		set in_date_lo       [reqGetArg date_lo]
		set in_date_hi       [reqGetArg date_hi]
		set in_date_sel      [reqGetArg date_sel]

		tpBindString  CategoryLink  $in_ev_category
		tpBindString  ClassIdLink   $in_ev_class_id
		tpBindString  ClassNameLink $in_ev_class_name
		tpBindString  TypeIdLink    $in_ev_type_id
		tpBindString  TypeNameLink  $in_ev_type_name
		tpBindString  EventIdLink   $in_ev_id
		tpBindString  EventNameLink $in_ev_name
		tpBindString  StartTimeLink $in_start_time
		tpBindString  DateLoLink    $in_date_lo
		tpBindString  DateHiLink    $in_date_hi
		tpBindString  DateSelLink   $in_date_sel

		debug_log_params "ShowUnsettleMarket"

		set where_clause "and m.ev_id = $in_ev_id"

		set sql "
				select
						m.ev_mkt_id,
						m.name,
						DECODE(m.settled,'Y',\"Settled\",'N',\"Not Settled\") settled_desc,
						m.settled,
						m.disporder,
						m.sort
				from
						tevmkt   m,
						tevocgrp g
				where m.ev_oc_grp_id = g.ev_oc_grp_id
				$where_clause
				order by m.disporder "

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $res]

		tpSetVar NumMarkets $nrows

		set MARKETARRAY(entries) $nrows

		for {set i 0} {$i<$nrows} {incr i} {
			set MARKETARRAY($i,market_id)     [db_get_col $res $i ev_mkt_id]
			set MARKETARRAY($i,name)          [db_get_col $res $i name]
			set MARKETARRAY($i,settled)       [db_get_col $res $i settled]
			set MARKETARRAY($i,settled_desc)  [db_get_col $res $i settled_desc]
			set MARKETARRAY($i,sort)          [db_get_col $res $i sort]
		}

		tpBindVar MarketId          MARKETARRAY market_id    c_idx
		tpBindVar MarketDesc        MARKETARRAY name         c_idx
		tpBindVar MarketSettled     MARKETARRAY settled      c_idx
		tpBindVar MarketSettledDesc MARKETARRAY settled_desc c_idx
		tpBindVar MarketSort        MARKETARRAY sort         c_idx

		asPlayFile unsettlement.html

		db_close $res

		log_debug "OUT show_unsettle_market"
}

# ----------------------------------------------------------------------------
# Display the settled status of the selections in the market - so the user can see
# what the effects of un-settling the market will be.
# ----------------------------------------------------------------------------
proc show_unsettle_selection args {

		log_debug "IN show_unsettle_selection"

		tpSetVar PlayScreen   "ShowUnsettleSelection"

		global DB SELECTIONARRAY

		if {[info exists SELECTIONARRAY]} { unset SELECTIONARRAY }

		set in_ev_category    [reqGetArg category]
		set in_ev_class_id    [reqGetArg class_id]
		set in_ev_class_name  [reqGetArg class_name]
		set in_ev_type_id     [reqGetArg type_id]
		set in_ev_type_name   [reqGetArg type_name]
		set in_ev_id          [reqGetArg event_id]
		set in_ev_name        [reqGetArg event_name]
		set in_start_time     [reqGetArg start_time]
		set in_market_id      [reqGetArg market_id]
		set in_market_name    [reqGetArg market_name]
		set in_market_sort    [reqGetArg market_sort]
		set in_date_lo        [reqGetArg date_lo]
		set in_date_hi        [reqGetArg date_hi]
		set in_date_sel       [reqGetArg date_sel]

		tpBindString  CategoryLink   $in_ev_category
		tpBindString  ClassIdLink    $in_ev_class_id
		tpBindString  ClassNameLink  $in_ev_class_name
		tpBindString  TypeIdLink     $in_ev_type_id
		tpBindString  TypeNameLink   $in_ev_type_name
		tpBindString  EventIdLink    $in_ev_id
		tpBindString  EventNameLink  $in_ev_name
		tpBindString  StartTimeLink  $in_start_time
		tpBindString  MarketIdLink   $in_market_id
		tpBindString  MarketNameLink $in_market_name
		tpBindString  MarketSortLink $in_market_sort
		tpBindString  DateLoLink     $in_date_lo
		tpBindString  DateHiLink     $in_date_hi
		tpBindString  DateSelLink    $in_date_sel

		debug_log_params "ShowUnsettleSelection"

		if {$in_market_sort == "CW"} {
			set sql [subst {
				select
					b.bir_index,
					b.settled,
					b.mkt_bir_idx,
					s.ev_oc_id,
					s.desc,
					DECODE(b.settled,'Y','Settled','N','Not Settled') settled_desc,
					case
						when b.result_conf = 'Y'
						then NVL(r.result,b.default_res)
						else '-'
					end as result,
					s.disporder
				from
					tMktBirIdx b,
					outer tMktBirIdxRes r,
					tEvOc s
				where
					b.ev_mkt_id = ? and
					s.ev_mkt_id = b.ev_mkt_id and
					b.mkt_bir_idx = r.mkt_bir_idx and
					r.ev_oc_id = s.ev_oc_id
				order by
					b.bir_index,
					s.disporder
			}]
			tpSetVar is_cw 1
		} else {
			set sql [subst {
				select
					ev_oc_id,
					desc,
					DECODE(settled,'Y','Settled','N','Not Settled') settled_desc,
					settled,
					result,
					disporder
				from
					tevoc
				where
					ev_mkt_id = ?
				order by
					disporder
			}]
			tpSetVar is_cw 0
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $in_market_id]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $res]

		tpSetVar NumSelections $nrows

		set SELECTIONARRAY(entries) $nrows

		if {$nrows > 0} {
			if {$in_market_sort == "CW"} {

				# index_num here just refers to indexing in the array rather than the
				# actual bir index
				set index_num -1
				set previous_bir_index -1

				for {set i 0} {$i<$nrows} {incr i} {

					set current_bir_index [db_get_col $res $i bir_index]
					if {$current_bir_index != $previous_bir_index} {

						# used to store num of selns for index market, wont be correct on the first iteration
						# also should really be the same for all bir indexes, but we'll set it anyway for each
						# bir index
						if {$i != 0} { set SELECTIONARRAY($index_num,num_selns) [incr seln_num] }

						incr index_num
						set seln_num -1
						set SELECTIONARRAY($index_num,bir_index)  [db_get_col $res $i bir_index]
						set SELECTIONARRAY($index_num,desc)       [ADMIN::BIR::subst_xth $in_market_name [db_get_col $res $i bir_index] CW]
						set SELECTIONARRAY($index_num,settled)    [db_get_col $res $i settled]
						set SELECTIONARRAY($index_num,mkt_bir_id) [db_get_col $res $i mkt_bir_idx]
					}

					incr seln_num
					set SELECTIONARRAY($index_num,$seln_num,sel_id)       [db_get_col $res $i ev_oc_id]
					set SELECTIONARRAY($index_num,$seln_num,desc)         [db_get_col $res $i desc]
					set SELECTIONARRAY($index_num,$seln_num,settled_desc) [db_get_col $res $i settled_desc]
					set SELECTIONARRAY($index_num,$seln_num,result)       [db_get_col $res $i result]

					set previous_bir_index $current_bir_index
				}

				# still need to set num_selns for current index market
				set SELECTIONARRAY($index_num,num_selns) [incr seln_num]

				set SELECTIONARRAY(num_indexes) [incr index_num]

				tpBindVar BirIndex             SELECTIONARRAY bir_index    b_idx
				tpBindVar IndexDesc            SELECTIONARRAY desc         b_idx
				tpBindVar IndexSettled         SELECTIONARRAY settled      b_idx
				tpBindVar MarketBirId          SELECTIONARRAY mkt_bir_id   b_idx
				tpBindVar SelectionId          SELECTIONARRAY sel_id       b_idx c_idx
				tpBindVar SelectionDesc        SELECTIONARRAY desc         b_idx c_idx
				tpBindVar SelectionSettledDesc SELECTIONARRAY settled_desc b_idx c_idx
				tpBindVar SelectionResult      SELECTIONARRAY result       b_idx c_idx

			} else {

				for {set i 0} {$i<$nrows} {incr i} {
					set SELECTIONARRAY($i,sel_id)       [db_get_col $res $i ev_oc_id]
					set SELECTIONARRAY($i,desc)         [db_get_col $res $i desc]
					set SELECTIONARRAY($i,settled)      [db_get_col $res $i settled]
					set SELECTIONARRAY($i,settled_desc) [db_get_col $res $i settled_desc]
					set SELECTIONARRAY($i,result)       [db_get_col $res $i result]
				}

				tpBindVar SelectionId          SELECTIONARRAY sel_id       c_idx
				tpBindVar SelectionDesc        SELECTIONARRAY desc         c_idx
				tpBindVar SelectionSettled     SELECTIONARRAY settled      c_idx
				tpBindVar SelectionSettledDesc SELECTIONARRAY settled_desc c_idx
				tpBindVar SelectionResult      SELECTIONARRAY result       c_idx
			}
		}

		asPlayFile unsettlement.html

		db_close $res

		log_debug "OUT show_unsettle_selection"
}

# ----------------------------------------------------------------------------
# Proc used to
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# This procedure displays details of the market or the selection that the user
# is about to unsettle. The parameter unstl_type determines whether a Market (M)
# or a Selection (S) should be displayed.
# ----------------------------------------------------------------------------
proc check_unsettle args {

		log_debug "IN check_unsettle"

		tpSetVar PlayScreen      "CheckUnsettle"

		set in_ev_category    [reqGetArg category]
		set in_ev_class_id    [reqGetArg class_id]
		set in_ev_class_name  [reqGetArg class_name]
		set in_ev_type_id     [reqGetArg type_id]
		set in_ev_type_name   [reqGetArg type_name]
		set in_ev_id          [reqGetArg event_id]
		set in_ev_name        [reqGetArg event_name]
		set in_start_time     [reqGetArg start_time]
		set in_market_id      [reqGetArg market_id]
		set in_market_name    [reqGetArg market_name]
		set in_date_lo        [reqGetArg date_lo]
		set in_date_hi        [reqGetArg date_hi]
		set in_date_sel       [reqGetArg date_sel]
		set in_unstl_type     [reqGetArg unstl_type]

		tpBindString  CategoryLink   $in_ev_category
		tpBindString  ClassIdLink    $in_ev_class_id
		tpBindString  ClassNameLink  $in_ev_class_name
		tpBindString  TypeIdLink     $in_ev_type_id
		tpBindString  TypeNameLink   $in_ev_type_name
		tpBindString  EventIdLink    $in_ev_id
		tpBindString  EventNameLink  $in_ev_name
		tpBindString  StartTimeLink  $in_start_time
		tpBindString  MarketIdLink   $in_market_id
		tpBindString  MarketNameLink $in_market_name
		tpBindString  DateLoLink     $in_date_lo
		tpBindString  DateHiLink     $in_date_hi
		tpBindString  DateSelLink    $in_date_sel
		tpBindString  UnstlTypeLink  $in_unstl_type

		if {$in_unstl_type == "S"} {
			set in_sel_id      [reqGetArg sel_id]
			set in_sel_name    [reqGetArg sel_name]
			set in_market_sort [reqGetArg market_sort]

			tpBindString  SelectionIdLink   $in_sel_id
			tpBindString  SelectionNameLink $in_sel_name
			tpBindString  MarketSortLink    $in_market_sort
			tpBindString  Title             "Unsettle Selection"
		} elseif {$in_unstl_type == "M"} {
			tpBindString  Title             "Unsettle Market"
		} elseif {$in_unstl_type == "E"} {
			tpBindString  Title             "Unsettle Event"
		} elseif {$in_unstl_type == "B"} {
			tpBindString  Title             "Unsettle BIR Index"
			tpBindString  BirIndex          [reqGetArg bir_index]
			tpBindString  MarketSortLink    [reqGetArg market_sort]
			tpBindString  MarketBirIdLink   [reqGetArg market_bir_id]
		} elseif {$in_unstl_type == "A"} {
			tpBindString  Title             "Unsettle All BIR Indexes"
			tpBindString  BirIndex          "All"
		} else {
			error "Unsettlement type must be either M, S, A or B"
		}

		tpSetVar UnstlType  $in_unstl_type

		debug_log_params "CheckUnsettle"

		asPlayFile unsettlement.html

		log_debug "OUT check_unsettle"
}


# ----------------------------------------------------------------------------
# The user has clicked and decided to unsettle the market or selection. The
# parameter unstl_type determines whether a Market (M), Selection (S) or
# BIR Indexed Market (B) is being unsettled by the user.
# ----------------------------------------------------------------------------
proc do_unsettle args {

		tpSetVar PlayScreen  "DoUnsettle"

		log_debug "IN do_unsettle"

		global DB USERID USERNAME BETS_UNSTL_ARRAY

		variable unstl_log_file

		set in_unstl_type     [reqGetArg unstl_type]

		set in_ev_category    [reqGetArg category]
		set in_ev_class_id    [reqGetArg class_id]
		set in_ev_class_name  [reqGetArg class_name]
		set in_ev_type_id     [reqGetArg type_id]
		set in_ev_type_name   [reqGetArg type_name]
		set in_ev_id          [reqGetArg event_id]
		set in_ev_name        [reqGetArg event_name]
		set in_bet_receipt    [reqGetArg bet_receipt]
		set in_bet_id         [reqGetArg bet_id]
		set in_start_time     [reqGetArg start_time]
		set in_market_id      [reqGetArg market_id]
		set in_market_name    [reqGetArg market_name]
		set in_date_lo        [reqGetArg date_lo]
		set in_date_hi        [reqGetArg date_hi]
		set in_date_sel       [reqGetArg date_sel]

		tpBindString  CategoryLink   $in_ev_category
		tpBindString  ClassIdLink    $in_ev_class_id
		tpBindString  ClassNameLink  $in_ev_class_name
		tpBindString  TypeIdLink     $in_ev_type_id
		tpBindString  TypeNameLink   $in_ev_type_name
		tpBindString  EventIdLink    $in_ev_id
		tpBindString  EventNameLink  $in_ev_name
		tpBindString  BetId          $in_bet_id
		tpBindString  BetReceipt     $in_bet_receipt
		tpBindString  StartTimeLink  $in_start_time
		tpBindString  MarketIdLink   $in_market_id
		tpBindString  MarketNameLink $in_market_name
		tpBindString  DateLoLink     $in_date_lo
		tpBindString  DateHiLink     $in_date_hi
		tpBindString  DateSelLink    $in_date_sel
		tpBindString  Username       $USERNAME

		set exec_start_time          [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
		tpBindString  Time           $exec_start_time

		# If we are settling market then we require additional
		# parameters.

		tpSetVar    UnstlType $in_unstl_type

		if { $in_unstl_type == "S" } {

			# Get and bind arguments supplied to identify Selection

			set in_sel_id      [reqGetArg sel_id]
			set in_sel_name    [reqGetArg sel_name]
			set in_market_sort [reqGetArg market_sort]

			tpBindString  SelectionIdLink    $in_sel_id
			tpBindString  SelectionNameLink  $in_sel_name
			tpBindString  MarketSortLink     $in_market_sort
			tpBindString  Title              "Selection Unsettled"

			log_debug  "Un-settling selection id : $in_sel_id"

			set id $in_sel_id

		} elseif {$in_unstl_type == "M"} {

			tpBindString  Title       "Market Unsettled"
			log_debug "Un-settling market id : $in_market_id"

			set id $in_market_id

		} elseif {$in_unstl_type == "E"} {

			tpBindString  Title       "Event Unsettled"
			log_debug "Un-settling event id : $in_ev_id"

			set id $in_ev_id

		} elseif {$in_unstl_type == "B"} {

			set in_market_sort   [reqGetArg market_sort]
			set in_market_bir_id [reqGetArg market_bir_id]
			set in_bir_index     [reqGetArg bir_index]

			tpBindString  MarketBirIdLink $in_market_bir_id
			tpBindString  MarketSortLink  $in_market_sort
			tpBindString  Title           "BIR Index Unsettled"

			log_debug "Un-settling bir indexed market with mkt_bir_idx : $in_market_bir_id"

			set id $in_market_bir_id

		} elseif {$in_unstl_type == "A"} {

			tpBindString  Title "All BIR Indexes Unsettled"
			log_debug "Un-settling all bir indexes for market id : $in_market_id"

			set id $in_market_id

		} elseif {$in_unstl_type == "BET"} {
			tpBindString Title "Bet Unsettled From Bet Receipt"
			log_debug "Un-settling bet with bet receipt : $in_bet_receipt"

			set id $in_bet_id

		} else {
			error "Unsettlement type must be either E, M, S, A, B or BET"
		}

		debug_log_params "DoUnsettle"

		set bad 0

		if {![op_allowed UnSettle]} {
				set Message "You don't have permission to perform unsettlement."
				tpSetVar Status -1
		} else {

			open_unstl_log $in_unstl_type $id


			log_unstl "\[Start\]"
			log_break
			if {$in_unstl_type == "E"} {
				log_unstl "Unsettling Event #$id "
			} elseif  {$in_unstl_type == "M"} {
				log_unstl "Unsettling Market #$id "
			} elseif {$in_unstl_type == "S"} {
				log_unstl "Unsettling Selection #$id"
			} elseif {$in_unstl_type == "B"} {
				log_unstl "Unsettling Market Bir Id #$id"
			} elseif {$in_unstl_type == "A"} {
				log_unstl "Unsettling All BIR Indexes for Market #$id"
			} elseif {$in_unstl_type == "BET"} {
				log_unstl "Unsettling Bet for Bet Receipt #$id"
			}
			log_unstl "User : $USERNAME"
			log_unstl "Time : $exec_start_time"
			log_break
			log_unstl "Event      : $in_ev_name"
			log_unstl "Start time : $in_start_time"

			if {$in_unstl_type != "E"} {
				log_unstl "Market     : $in_market_name"
			}
			if  {$in_unstl_type == "S"} {
				log_unstl "Selection  : $in_sel_name"
			}
			if  {$in_unstl_type == "B"} {
				log_unstl "Bir Index  : $in_bir_index"
			}
			if  {$in_unstl_type == "A"} {
				log_unstl "Bir Index  : All"
			}

			log_unstl "======= BEFORE ===================================="
			log_unstl_status $in_unstl_type $id
			log_break

			log_debug "Parameters : $in_unstl_type $id $USERNAME $USERID"

			if {$in_unstl_type != "BET"} {
				# Run the pUnsettleBets procedure with the 'M','S' or 'B' parameter.

				set sql {
					execute procedure pUnsettleBets(
						p_type    = ?,
						p_id      = ?,
						p_adminuser = ?,
						p_auto_dh = ?
					)
				}

				set stmt [inf_prep_sql $DB $sql]

				log_debug "sql : $sql"

				log_unstl "Performing unsettlement..."

				if {[catch {
					set res [inf_exec_stmt $stmt $in_unstl_type\
												$id          \
												$USERNAME    \
												[OT_CfgGet FUNC_AUTO_DH 0]]
				} msg]} {
					log_debug "ERROR executing unsettlebets stored procedure ..."
					log_unstl "...failed."
					log_unstl "ERROR $msg"
					err_bind $msg
					set bad 1
				} else {
					log_unstl "...completed successfully."
				}

				inf_close_stmt $stmt

			} else {
				# Run the pUnsettleBet procedure for a single bet
				set sql [subst {
					execute procedure pUnsettleBet(
						p_type    = ?,
						p_bet_id  = ?,
						p_user_id = ?
					)
				}]

				set stmt [inf_prep_sql $DB $sql]

				if {[catch {
					set res [inf_exec_stmt $stmt $in_unstl_type $in_bet_id $USERID]
				} msg]} {
					log_debug "ERROR executing unsettlebet stored procedure ..."
					log_unstl "...failed."
					log_unstl "ERROR $msg"
					err_bind $msg
					set bad 1
				} else {
					log_unstl "...completed successfully."
				}

				inf_close_stmt $stmt
			}


			log_unstl "======= AFTER ====================================="
			log_unstl_status $in_unstl_type $id
			log_break

			if { ($bad == 1) } {
				OT_LogWrite 5 "ERROR : Unsettlement attempt failed."

				if {$in_unstl_type == "M"} {
					set Message "Error : Could not unsettle market : #$id"
				} elseif {$in_unstl_type == "E"} {
					set Message "Error : Could not unsettle event : #$id"
				} elseif {$in_unstl_type == "S"} {
					set Message "Error : Could not unsettle selection : #$id"
				} elseif {$in_unstl_type == "B"} {
					set Message "Error : Could not unsettle market bir id : #$id"
				} elseif {$in_unstl_type == "A"} {
					set Message "Error : Could not unsettle all indexes for market : #$id"
				} elseif {$in_unstl_type == "BET"} {
					set Message "Error : Could not unsettle bet with receipt : #$id"
				} else {
					error "Unsettlement type must be either E, M, S, A, B or BET"
				}

				log_unstl "$Message"

				tpSetVar Status 1

			} else {
				if {$in_unstl_type == "M"} {
					set Message "Successfully unsettled market : \"$in_market_name\" (id #$id)"
				} elseif {$in_unstl_type == "E"} {
					set Message "Successfully unsettled event : \"$in_ev_name\" (id #$id)"
				} elseif {$in_unstl_type == "S"} {
					set Message "Successfully unsettled selection : \"$in_sel_name\" (id #$id)"
				} elseif {$in_unstl_type == "B"} {
					set Message "Successfully unsettled bir index market : \"[ADMIN::BIR::subst_xth $in_market_name $in_bir_index CW]\" (id #$id)"
				} elseif {$in_unstl_type == "A"} {
					set Message "Successfully unsettled all indexes  : \"$in_market_name\" (id #$id)"
				} elseif {$in_unstl_type == "BET"} {
					set Message "Successfully unsettled bet with receipt #$id"
				} else {
					error "Unsettlement type must be either E, M, S, A, B or BET"
				}

				tpSetVar Status 0
			}

		}

	   if { ($bad == 0) } {

			# To provide the operator with some measure of the imapct they have had
			# by performing this un-settlement we display whose accounts have gone negative after
			# having their winings revoked, and the number of individual bets that were un-settled.

			set num_cust_neg_bal -1
			set num_bet_types    -1
			set num_cust_readj   -1

			catch {unset BETS_UNSTL_ARRAY}


			cal_num_bets_unsettled $id $in_unstl_type
			cal_num_cust_neg_bal   $id $in_unstl_type
			cal_num_cust_readj     $id $in_unstl_type

			tpSetVar      NumAccountsVar   $num_cust_neg_bal
			tpSetVar      NumBetsUnsettled $num_bet_types
			tpSetVar      NumAcctsReadjVar $num_cust_readj

			tpBindString  NumAccounts    $num_cust_neg_bal
			tpBindString  NumBetTypes    $num_bet_types
			tpBindString  NumAcctsReadj  $num_cust_readj

	   }

	   tpBindString  Message $Message

	   close_unstl_log

	   asPlayFile unsettlement.html

	   log_debug "OUT do_unsettle"
}


# ----------------------------------------------------------------------------
# Calcalate the number of customers whose accounts are negative as a result
# of their winnings being revoked after unsettlement.
# ----------------------------------------------------------------------------
proc cal_num_cust_readj {p_id p_type} {

		global DB

		log_debug "IN cal_num_cust_readj"

		upvar 1 num_cust_readj  l_num_cust_readj

		if {$p_type == "E"} {
			set from_clause ""
			set where_clause "where e.ev_id = $p_id and"
		} elseif {$p_type == "M"} {
			set from_clause ""
			set where_clause "where oc.ev_mkt_id = $p_id and"
		} elseif {$p_type == "S"} {
			set from_clause ""
			set where_clause "where oc.ev_oc_id = $p_id and"
		} elseif {$p_type == "B"} {
			set from_clause "tMktBirIdx bi,"
			set where_clause [subst {
				where
					bi.mkt_bir_idx = $p_id and
					ob.bir_index = bi.bir_index and
					oc.ev_mkt_id = bi.ev_mkt_id and
			}]
		} elseif {$p_type == "A"} {
			set from_clause "tMktBirIdx i,"
			set where_clause "where oc.ev_mkt_id = $p_id and i.ev_mkt_id = oc.ev_mkt_id and
				 i.bir_index = ob.bir_index and"
		} elseif {$p_type == "BET"} {
			set from_clause ""
			set where_clause "where b.bet_id = $p_id and"
		} else {
			error "Unsettlement type must be either E, M, S, A or B"
		}

		set sql "
				select
					j.amount as adj,
					c.username,
					c.cust_id,
					a.balance
				from
					$from_clause
					tobet     ob,
					tbet      b,
					tevoc     oc,
					tev       e,
					tevtype   t,
					tevclass  ec,
					outer (tmanadj m, tjrnl j),
					tacct     a,
					tcustomer c
				$where_clause
				    oc.ev_oc_id    = ob.ev_oc_id   and
					ob.bet_id      = b.bet_id      and
					oc.ev_id       = e.ev_id       and
					e.ev_type_id   = t.ev_type_id  and
					ec.ev_class_id = t.ev_class_id and
					b.acct_id      = a.acct_id     and
					a.cust_id      = c.cust_id     and
					j.acct_id      = a.acct_id     and
					j.j_op_type    = 'MAN'         and
					j.j_op_ref_key = 'MADJ'        and
					m.acct_id      = a.acct_id     and
					j.j_op_ref_id  = m.madj_id     and
					j.desc like 'Resettlement Adjustment for bet: '||b.bet_id"

		log_debug "cal_num_cust_neg_bal sql : $sql"

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		# Set the number of customers with negative balances to the
		# variable defined in the calling procedure.

		set l_num_cust_readj 0
		set count 0

		log_break

		for {set i 0} {$i< [db_get_nrows $res]} {incr i} {
			if {[db_get_col $res $i adj] != ""} {
				incr l_num_cust_readj
				set readjstr($count) "${l_num_cust_readj}) Cust id : [db_get_col $res $i cust_id]\tUsername : [db_get_col $res $i username]\tBal : [db_get_col $res $i balance]\tAdjustment : [db_get_col $res $i adj] "
				incr count
			}
		}
		set readjstr(num) $count

		if {$l_num_cust_readj > 0} {

			if {$l_num_cust_readj==1} {
				log_unstl "Warning : $l_num_cust_readj customers readjusted from negative;"
			} else {
				log_unstl "Warning : $l_num_cust_readj customers readjusted from negative;"
			}

			for {set i 0} {$i< $readjstr(num)} {incr i} {
				log_unstl $readjstr($i)
			}

		} else  {
			log_unstl "No customer balances were readjusted."
		}

		log_break

		log_debug "OUT cal_num_cust_readj"

}

# ----------------------------------------------------------------------------
# Calcalate the number of customers whose accounts are negative as a result
# of their winnings being revoked after unsettlement.
# ----------------------------------------------------------------------------
proc cal_num_cust_neg_bal {p_id p_type} {

		global DB

		log_debug "IN cal_num_cust_neg_bal"

		upvar 1 num_cust_neg_bal  l_num_cust_neg_bal

		if {$p_type == "E"} {
			set from_clause  "tevoc e,"
			set where_clause "where e.ev_id = $p_id and o.ev_oc_id = e.ev_oc_id"
		} elseif {$p_type == "M"} {
			set from_clause  "tevoc e,"
			set where_clause "where e.ev_mkt_id = $p_id and o.ev_oc_id = e.ev_oc_id"
		} elseif {$p_type == "S"} {
			set from_clause  ""
			set where_clause "where o.ev_oc_id = $p_id"
		} elseif {$p_type == "B"} {
			set from_clause "tMktBirIdx i, tEvOc s,"
			set where_clause "where i.mkt_bir_idx = $p_id and o.bir_index = i.bir_index and \
				i.ev_mkt_id = s.ev_mkt_id and o.ev_oc_id = s.ev_oc_id"
		} elseif {$p_type == "A"} {
			set from_clause "tMktBirIdx i, tEvOc s,"
			set where_clause "where s.ev_mkt_id = $p_id and o.ev_oc_id = s.ev_oc_id and
				i.ev_mkt_id = s.ev_mkt_id and i.bir_index = o.bir_index"
		} elseif {$p_type == "BET"} {
			set from_clause ""
			set where_clause "where b.bet_id = $p_id"
		} else {
			error "Unsettlement type must be either E, M, S, A or B"
		}

		set sql "
				select
				   distinct(a.acct_id) acct_id,
				   a.cust_id           cust_id,
				   a.balance           balance,
				   c.username          username
				from
				   $from_clause
				   tobet o,
				   tbet  b,
				   tjrnl j,
				   tacct a,
				   tcustomer c
				$where_clause
				and b.bet_id   = o.bet_id
				and j.j_op_ref_id = b.bet_id
				and j.j_op_type in ('BUST','BUWN','BURF')
				and j.balance  < 0
				and j.acct_id = a.acct_id
				and a.balance < 0
				and a.cust_id = c.cust_id"

		log_debug "cal_num_cust_neg_bal sql : $sql"

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		# Set the number of customers with negative balances to the
		# variable defined in the calling procedure.

		set l_num_cust_neg_bal [db_get_nrows $res]

		log_break

		if {$l_num_cust_neg_bal > 0} {

			if {$l_num_cust_neg_bal==1} {
				log_unstl "Warning : $l_num_cust_neg_bal customer now has a negative balance;"
			} else {
				log_unstl "Warning : $l_num_cust_neg_bal customers now have a negative balance;"
			}

			for {set i 0} {$i<$l_num_cust_neg_bal} {incr i} {
				log_unstl "[expr {$i + 1}]) Cust id : [db_get_col $res $i cust_id]\tUsername : [db_get_col $res $i username]\tBal : [db_get_col $res $i balance]"
			}

		} else  {
			log_unstl "No customer balances were set to negative."
		}

		log_break

		log_debug "OUT cal_num_cust_neg_bal"

}

# ----------------------------------------------------------------------------
# Procedure to calculate the number of individual bets that were unsettled as a result of
# unsettling the market/selection, and group these according to type.
# ----------------------------------------------------------------------------
proc cal_num_bets_unsettled {p_id p_type} {

		global DB BETS_UNSTL_ARRAY

		log_debug "IN cal_num_bets_unsettled"

		upvar 1 num_bet_types       l_num_bet_types

		if {$p_type == "E"} {
			set from_clause  "tevoc e,"
			set where_clause "where e.ev_id = $p_id and o.ev_oc_id = e.ev_oc_id"
		} elseif {$p_type == "M"} {
			set from_clause  "tevoc e,"
			set where_clause "where e.ev_mkt_id = $p_id and o.ev_oc_id = e.ev_oc_id"
		} elseif {$p_type == "S"} {
			set from_clause  ""
			set where_clause "where o.ev_oc_id  = $p_id"
		} elseif {$p_type == "B"} {
			set from_clause "tMktBirIdx i, tEvOc s,"
			set where_clause "where i.mkt_bir_idx = $p_id and o.bir_index = i.bir_index and
				i.ev_mkt_id = s.ev_mkt_id and o.ev_oc_id = s.ev_oc_id"
		} elseif {$p_type == "A"} {
			set from_clause "tMktBirIdx i, tEvOc s,"
			set where_clause "where s.ev_mkt_id = $p_id and o.ev_oc_id = s.ev_oc_id and
				i.ev_mkt_id = s.ev_mkt_id and i.bir_index = o.bir_index"
		} elseif {$p_type == "BET"} {
			set from_clause ""
			set where_clause "where b.bet_id = $p_id"
		} else {
			error "Unsettlement type must be either E, M, S, A or B"
		}

		set sql "
				select
				   b.bet_type,
				   count(b.bet_id) total
				from
				   $from_clause
				   tobet o,
				   tbet  b
				$where_clause
				and o.bet_id   = b.bet_id
				group by b.bet_type"

		log_debug "cal_num_bets_unsettled sql : $sql"

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $res]

		log_debug "Number of different types of bet unsettled : $nrows"

		tpSetVar NumBetTypes $nrows

		set l_num_bet_types           $nrows
		set BETS_UNSTL_ARRAY(entries) $nrows

		if {$nrows == 0 } {
			log_unstl  "There were no bets to unsettle."
		} else {
			log_unstl  "Number of different types of bet unsettled;"
		}

		for {set i 0} {$i<$nrows} {incr i} {
			set bt                              [db_get_col $res $i bet_type]
			set tot                             [db_get_col $res $i total]

			set BETS_UNSTL_ARRAY($i,bet_type)      $bt
			set BETS_UNSTL_ARRAY($i,total)         $tot

			log_unstl "$bt		$tot"
		}

		tpBindVar BetType          BETS_UNSTL_ARRAY bet_type      c_idx
		tpBindVar BetTotal         BETS_UNSTL_ARRAY total         c_idx

		log_debug "OUT cal_num_bets_unsettled"
}


# ----------------------------------------------------------------------------
# If a bet is unsettled and winnings are revoked then some customers accounts
# might now have a negative balance and BEEN READJUSTED! This screen will display a list of such
# customers so that the operator can follow up on this.
# ----------------------------------------------------------------------------

proc show_unsettle_adj_accts args {

		tpSetVar PlayScreen  "ShowUnsettleAdjAccts"

		log_debug "IN show_unsettle_adj_accts"

		global DB CUSTARRAY

		set in_ev_category    [reqGetArg category]
		set in_ev_class_id    [reqGetArg class_id]
		set in_ev_class_name  [reqGetArg class_name]
		set in_ev_type_id     [reqGetArg type_id]
		set in_ev_type_name   [reqGetArg type_name]
		set in_ev_id          [reqGetArg event_id]
		set in_ev_name        [reqGetArg event_name]
		set in_start_time     [reqGetArg start_time]
		set in_market_id      [reqGetArg market_id]
		set in_market_name    [reqGetArg market_name]
		set in_date_lo        [reqGetArg date_lo]
		set in_date_hi        [reqGetArg date_hi]
		set in_date_sel       [reqGetArg date_sel]
		set in_unstl_type     [reqGetArg unstl_type]

		tpBindString  CategoryLink   $in_ev_category
		tpBindString  ClassIdLink    $in_ev_class_id
		tpBindString  ClassNameLink  $in_ev_class_name
		tpBindString  TypeIdLink     $in_ev_type_id
		tpBindString  TypeNameLink   $in_ev_type_name
		tpBindString  EventIdLink    $in_ev_id
		tpBindString  EventNameLink  $in_ev_name
		tpBindString  StartTimeLink  $in_start_time
		tpBindString  MarketIdLink   $in_market_id
		tpBindString  MarketNameLink $in_market_name
		tpBindString  DateLoLink     $in_date_lo
		tpBindString  DateHiLink     $in_date_hi
		tpBindString  DateSelLink    $in_date_sel

		if { $in_unstl_type == "S" } {

			# Get and bind arguments supplied to identify Selection

			set in_sel_id      [reqGetArg sel_id]
			set in_sel_name    [reqGetArg sel_name]

			tpBindString  SelectionIdLink    $in_sel_id
			tpBindString  SelectionNameLink  $in_sel_name

			log_debug  "Checking Negative accounts selection id : $in_sel_id"

			set id $in_sel_id

		} elseif {$in_unstl_type == "M" || $in_unstl_type == "A"} {

			log_debug  "Checking Negative accounts market id : $in_market_id"

			set id $in_market_id

		} elseif {$in_unstl_type == "E"} {

			log_debug  "Checking Negative accounts event id : $in_ev_id"

			set id $in_ev_id

		} elseif {$in_unstl_type == "B"} {

			set in_market_bir_id [reqGetArg market_bir_id]

			tpBindString MarketBirIdLink $in_market_bir_id

			log_debug  "Checking Negative accounts market bir id : $in_market_bir_id"

			set id $in_market_bir_id

		} else {
			error "Unsettlement type must be either M, S, A or B"
		}

		debug_log_params "ShowUnsettleAdjAccts"

		if { $in_unstl_type == "S" } {
			set from_clause ""
			set where_clause "where oc.ev_oc_id = $in_sel_id and"
		} elseif {$in_unstl_type == "M"} {
			set from_clause ""
			set where_clause "where oc.ev_mkt_id = $in_market_id and"
		} elseif {$in_unstl_type == "E"} {
			set from_clause ""
			set where_clause "where e.ev_id = $in_ev_id and"
		} elseif {$in_unstl_type == "B"} {
			set from_clause "tMktBirIdx bi,"
			set where_clause [subst {
				where
					bi.mkt_bir_idx = $in_market_bir_id and
					ob.bir_index = bi.bir_index and
					oc.ev_mkt_id = bi.ev_mkt_id and
			}]
		} elseif {$in_unstl_type == "A"} {
			set from_clause "tMktBirIdx i,"
			set where_clause "where oc.ev_mkt_id = $in_market_id and i.ev_mkt_id = oc.ev_mkt_id and
				 i.bir_index = ob.bir_index and"
		} else {
			error "Unsettlement type must be either M, S, A or B"
		}

		set sql "
				select
					a.acct_id,
					c.username username,
					a.balance  balance,
					j.amount   adj
				from
					$from_clause
					tobet     ob,
					tbet      b,
					tevoc     oc,
					tev       e,
					tevtype   t,
					tevclass  ec,
					outer (tmanadj m, tjrnl j),
					tacct     a,
					tcustomer c
				$where_clause
					oc.ev_oc_id    = ob.ev_oc_id   and
					ob.bet_id      = b.bet_id      and
					oc.ev_id       = e.ev_id       and
					e.ev_type_id   = t.ev_type_id  and
					ec.ev_class_id = t.ev_class_id and
					b.acct_id      = a.acct_id     and
					a.cust_id      = c.cust_id     and
					j.acct_id      = a.acct_id     and
					j.j_op_type    = 'MAN'         and
					j.j_op_ref_key = 'MADJ'        and
					m.acct_id      = a.acct_id     and
					j.j_op_ref_id  = m.madj_id     and
					j.desc like 'Resettlement Adjustment for bet: '||b.bet_id
		log_debug "$sql"

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $res]

		tpSetVar NumCustNegAccts $nrows

		set CUSTARRAY(entries) $nrows
		set count 0

		for {set i 0} {$i<$nrows} {incr i} {
			if {[db_get_col $res $i adj] != ""} {
				set CUSTARRAY($count,acct_id)       [db_get_col $res $i acct_id]
				set CUSTARRAY($count,balance)       [db_get_col $res $i balance]
				set CUSTARRAY($count,adj)       	[db_get_col $res $i adj]
				set CUSTARRAY($count,username)      [db_get_col $res $i username]
				incr count
			}
		}

		tpBindVar AcctId          CUSTARRAY acct_id       c_idx
		tpBindVar Balance         CUSTARRAY balance       c_idx
		tpBindVar Adj             CUSTARRAY adj           c_idx
		tpBindVar Username        CUSTARRAY username      c_idx

		asPlayFile unsettlement.html

		db_close $res

		log_debug "OUT show_unsettle_adj_accts"
}

# ----------------------------------------------------------------------------
# If a bet is unsettled and winnings are revoked then some customers accounts
# might now have a negative balance! This screen will display a list of such
# customers so that the operator can follow up on this.
# ----------------------------------------------------------------------------

proc show_unsettle_neg_accts args {

		tpSetVar PlayScreen  "ShowUnsettleNegAccts"

		log_debug "IN show_unsettle_neg_accts"

		global DB CUSTARRAY

		set in_ev_category    [reqGetArg category]
		set in_ev_class_id    [reqGetArg class_id]
		set in_ev_class_name  [reqGetArg class_name]
		set in_ev_type_id     [reqGetArg type_id]
		set in_ev_type_name   [reqGetArg type_name]
		set in_ev_id          [reqGetArg event_id]
		set in_ev_name        [reqGetArg event_name]
		set in_start_time     [reqGetArg start_time]
		set in_market_id      [reqGetArg market_id]
		set in_market_name    [reqGetArg market_name]
		set in_date_lo        [reqGetArg date_lo]
		set in_date_hi        [reqGetArg date_hi]
		set in_date_sel       [reqGetArg date_sel]
		set in_unstl_type     [reqGetArg unstl_type]

		tpBindString  CategoryLink   $in_ev_category
		tpBindString  ClassIdLink    $in_ev_class_id
		tpBindString  ClassNameLink  $in_ev_class_name
		tpBindString  TypeIdLink     $in_ev_type_id
		tpBindString  TypeNameLink   $in_ev_type_name
		tpBindString  EventIdLink    $in_ev_id
		tpBindString  EventNameLink  $in_ev_name
		tpBindString  StartTimeLink  $in_start_time
		tpBindString  MarketIdLink   $in_market_id
		tpBindString  MarketNameLink $in_market_name
		tpBindString  DateLoLink     $in_date_lo
		tpBindString  DateHiLink     $in_date_hi
		tpBindString  DateSelLink    $in_date_sel

		if { $in_unstl_type == "S" } {

			# Get and bind arguments supplied to identify Selection

			set in_sel_id      [reqGetArg sel_id]
			set in_sel_name    [reqGetArg sel_name]

			tpBindString  SelectionIdLink    $in_sel_id
			tpBindString  SelectionNameLink  $in_sel_name

			log_debug  "Checking Negative accounts selection id : $in_sel_id"

			set id $in_sel_id

		} elseif {$in_unstl_type == "M" || $in_unstl_type == "A"} {

			log_debug  "Checking Negative accounts market id : $in_market_id"

			set id $in_market_id

		} elseif {$in_unstl_type == "E"} {

			log_debug  "Checking Negative accounts event id : $in_ev_id"

			set id $in_ev_id

		} elseif {$in_unstl_type == "B"} {

			set in_market_bir_id [reqGetArg market_bir_id]

			tpBindString MarketBirIdLink $in_market_bir_id

			log_debug  "Checking Negative accounts market bir id : $in_market_bir_id"

			set id $in_market_bir_id

		} else {
			error "Unsettlement type must be either E, M, S or B"
		}

		debug_log_params "ShowUnsettleNegAccts"

		if { $in_unstl_type == "S" } {
			set from_clause ""
			set where_clause "where e.ev_oc_id = $in_sel_id "
		} elseif {$in_unstl_type == "M"} {
			set from_clause ""
			set where_clause "where e.ev_mkt_id = $in_market_id"
		} elseif {$in_unstl_type == "E"} {
			set from_clause ""
			set where_clause "where e.ev_id = $in_ev_id"
		} elseif {$in_unstl_type == "B"} {
			set from_clause "tMktBirIdx bi,"
			set where_clause [subst {
				where
					bi.mkt_bir_idx = $in_market_bir_id and
					o.bir_index = bi.bir_index and
					e.ev_mkt_id = bi.ev_mkt_id
			}]
		} elseif {$in_unstl_type == "A"} {
			set from_clause "tMktBirIdx i,"
			set where_clause "where e.ev_mkt_id = $in_market_id and i.ev_mkt_id = e.ev_mkt_id and
				 i.bir_index = o.bir_index"
		} else {
			error "Unsettlement type must be either E, M, S, A or B"
		}

		set sql "
				select
					distinct(j.acct_id) acct_id,
					c.username username,
					a.balance balance
				from
					$from_clause
					tevoc e,
					tobet o,
					tbet  b,
					tjrnl j,
					tacct a,
					tcustomer c
				$where_clause
					and o.ev_oc_id = e.ev_oc_id
					and b.bet_id   = o.bet_id
					and j.j_op_ref_id = b.bet_id
					and j.j_op_type = ('BUWN','BURF','BUST')
					and j.balance  < 0
					and j.acct_id = a.acct_id
					and a.balance  < 0
					and a.cust_id = c.cust_id"

		log_debug "$sql"

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $res]

		tpSetVar NumCustNegAccts $nrows

		set CUSTARRAY(entries) $nrows

		for {set i 0} {$i<$nrows} {incr i} {
			set CUSTARRAY($i,acct_id)       [db_get_col $res $i acct_id]
			set CUSTARRAY($i,balance)       [db_get_col $res $i balance]
			set CUSTARRAY($i,username)      [db_get_col $res $i username]
		}

		tpBindVar AcctId          CUSTARRAY acct_id       c_idx
		tpBindVar Balance         CUSTARRAY balance       c_idx
		tpBindVar Username        CUSTARRAY username      c_idx

		asPlayFile unsettlement.html

		db_close $res

		log_debug "OUT show_unsettle_neg_accts"
}

# ----------------------------------------------------------------------------
# Open a dedicated log file with the format unstl_X_Z_YYYYMMDD_HHMMSS.log where
# is either 'M' for market or 'S' for selection and Z is the id number of the
# market or selection.  There will be one log file per unsettlement performed.
# The seconds granulaity in the log file name should  provide sufficient
# precision to avoid filename clashes.
# ----------------------------------------------------------------------------
proc open_unstl_log {p_type p_id} {

		log_debug "IN open_unstl_log"

		variable unstl_log_file

		set dir   [OT_CfgGet UNSTL_LOG_DIR      [OT_CfgGet LOG_DIR]]
		set level [OT_CfgGet UNSTL_LOG_LEVEL    [OT_CfgGet LOG_LEVEL]]
		set rota  [OT_CfgGet UNSTL_LOG_ROTATION [OT_CfgGet LOG_ROTATION]]

		set dt [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]
		set part1 "/unstl_"
		set us    "_"
		set part2 ".log"

		set dir_file [concat $dir$part1$p_type$us$p_id$us$dt$part2]

		log_debug "OT_LogOpen -level $level -rotation $rota -mode append $dir_file"

		if {[catch {set lf [OT_LogOpen -level $level -rotation $rota -mode append $dir_file]} msg]} {
			OT_LogWrite 1 "Failed to open log file: $msg"
		} else {
			OT_LogWrite 1 "Unsettlement open log file $dir_file opened successfully."
		}

		set unstl_log_file $lf

		log_debug "OUT open_unstl_log"

		return
}

proc close_unstl_log args {

	variable unstl_log_file
	log_unstl "\[End\]"

	OT_LogClose $unstl_log_file

}

# ----------------------------------------------------------------------------
# Write a string to the unsettlement log file and, using log_debug, also to the
# admin log file.
# ----------------------------------------------------------------------------
proc log_unstl {msg} {

		variable unstl_log_file

		log_debug "$msg"
		OT_LogWrite $unstl_log_file 1 "$msg"
}

# ----------------------------------------------------------------------------
# Insert line to format log file.
# ----------------------------------------------------------------------------
proc log_break args {

		variable unstl_log_file
		log_unstl "==================================================="

}

proc log_debug {msg} {

	 set debug_level 30
	 OT_LogWrite $debug_level "UNSTL: $msg"

}


# ----------------------------------------------------------------------------
# Since the stored procedure pUnsettleBets has no internal logging we must
# rely on comparing the before and after settled status of the market and its
# associated selections to be confident about what happened. This procedure
# is called before and after the execution of pUnsettleBets and records this
# information in the unsettlement log file.
# ----------------------------------------------------------------------------
proc log_unstl_status {p_type p_id}  {

	global DB

	# Two blocks of code - one for unsettling a Market, the other for unsettling a Selection.
	if { $p_type == "E" } {

		# Log details of the the event itself.

		set sql "select
						e.ev_id,
						e.desc,
						DECODE(e.settled,'Y',\"Settled\",'N',\"Not Settled\") settled_desc
				from
						tev e
				where
				        e.ev_id    = $p_id"

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $res]

		if { $nrows!=1 } {
			error "Event id #$p_id not in tev."
			return
		}

		log_unstl "EVENT     : [db_get_col $res 0 ev_id] : [db_get_col $res 0 desc] : [db_get_col $res 0 settled_desc] *"

		db_close $res


		# Log details of the the markets in the event.

		set sql "select
						m.ev_mkt_id,
						m.disporder
				from
						tevmkt   m
				where
				      m.ev_id    = $p_id
				order by m.disporder "

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $res]

		for {set i 0} {$i<$nrows} {incr i} {
			log_unstl_status M [db_get_col $res $i ev_mkt_id]
		}

		db_close $res

	} elseif { $p_type == "M" } {

		# Log details of the the market itself.

		set sql "select
						m.ev_mkt_id,
						m.name,
						DECODE(m.settled,'Y',\"Settled\",'N',\"Not Settled\") settled_desc,
						m.disporder
				from
						tevmkt   m
				where   m.ev_mkt_id    = $p_id
				order by m.disporder "

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $res]

		if { $nrows!=1 } {
			error "Market id #$p_id not in tevmkt."
			return
		}

		log_unstl "MARKET    : [db_get_col $res 0 ev_mkt_id] : [db_get_col $res 0 name] : [db_get_col $res 0 settled_desc] *"

		db_close $res


		# Log details of the selections in the market.

		set sql "
				select
						ev_oc_id,
						desc,
						DECODE(settled,'Y',\"Settled\",'N',\"Not Settled\") settled_desc,
						disporder
				from
						tevoc
				where ev_mkt_id = $p_id
				order by disporder "

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $res]

		for {set i 0} {$i<$nrows} {incr i} {

			log_unstl "SELECTION : [db_get_col $res $i ev_oc_id] : [db_get_col $res $i desc] : [db_get_col $res $i settled_desc]"

		}

		db_close $res

	} elseif { $p_type == "S" } {

		# Log details of the Market that the selection belongs to.

		set sql "select
						m.ev_mkt_id,
						m.name,
						DECODE(m.settled,'Y',\"Settled\",'N',\"Not Settled\") settled_desc,
						m.disporder
				from
						tevmkt   m,
						tevoc    o
				where o.ev_oc_id     = $p_id
				and   m.ev_mkt_id    = o.ev_mkt_id
				order by m.disporder "

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $res]

		if { $nrows!=1 } {
			error "Market id #$p_id not in tevmkt."
			return
		}

		log_unstl "MARKET    : [db_get_col $res 0 ev_mkt_id]  [db_get_col $res 0 name] [db_get_col $res 0 settled_desc]"

		db_close $res


		# Log details of all the selections in the same market.

		set sql "
				select
						e.ev_oc_id,
						e.desc,
						DECODE(e.settled,'Y',\"Settled\",'N',\"Not Settled\") settled_desc,
						e.disporder
				from
						tevoc e
				where e.ev_mkt_id = (select ev.ev_mkt_id from tevoc ev where ev.ev_oc_id = $p_id)
				order by disporder "

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $res]

		for {set i 0} {$i<$nrows} {incr i} {

			set the_ev_id [db_get_col $res $i ev_oc_id]

			# Mark the unsettled selection with an asterix in log file.

			if {$the_ev_id == $p_id} {
				set flag "*"
			} else {
				set flag  ""
			}

			log_unstl "SELECTION : $the_ev_id : [db_get_col $res $i desc] : [db_get_col $res $i settled_desc] $flag"
		}

		db_close $res

	} elseif { $p_type == "B" } {

		set sql [subst {
			select
				b.mkt_bir_idx,
				b.bir_index,
				m.name,
				DECODE(b.settled,'Y','Settled','N','Not Settled') settled_desc
			from
				tMktBirIdx b,
				tEvMkt m,
				tEvOcGrp g
			where
				g.ev_oc_grp_id = m.ev_oc_grp_id and
				m.ev_mkt_id = b.ev_mkt_id and
				b.ev_mkt_id =
					(select
						ev_mkt_id
					from
						tMktBirIdx
					where
						mkt_bir_idx = ?)
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $p_id]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $res]

		for {set i 0} {$i < $nrows} {incr i} {
			set the_mkt_bir_id [db_get_col $res $i mkt_bir_idx]

			# Mark the unsettled index with an asterix
			if {$the_mkt_bir_id == $p_id} {
				set flag "*"
			} else {
				set flag ""
			}

			log_unstl "BIR INDEX MARKET : $the_mkt_bir_id : [ADMIN::BIR::subst_xth [db_get_col $res $i name] [db_get_col $res $i bir_index] CW] \
			: [db_get_col $res $i settled_desc] $flag"
		}

		db_close $res

	} elseif { $p_type == "A" } {

		set sql [subst {
			select
				m.name,
				m.ev_mkt_id,
				DECODE(b.settled,'Y','Settled','N','Not Settled') settled_desc,
				b.mkt_bir_idx,
				b.bir_index
			from
				tEvMkt m,
				tMktBirIdx b
			where
				m.ev_mkt_id = ? and
				m.ev_mkt_id = b.ev_mkt_id
			}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $p_id]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $res]

		if {$nrows < 1} {
			error "Market id #$p_id not in tevmkt."
			return
		}

		log_unstl "MARKET    : [db_get_col $res 0 ev_mkt_id]  [db_get_col $res 0 name]"

		for {set i 0} {$i < $nrows} {incr i} {
			set the_mkt_bir_id [db_get_col $res $i mkt_bir_idx]
			log_unstl "BIR INDEX MARKET : $the_mkt_bir_id : [ADMIN::BIR::subst_xth [db_get_col $res $i name] [db_get_col $res $i bir_index] CW] \
			: [db_get_col $res $i settled_desc]"
		}

		db_close $res

	}
}

# ----------------------------------------------------------------------------
# This debug procedure is called for every screen loaded. It will print all the
# parameters for any procedure call to the log file at a configurable level.
# The parameter is just a label to be used in the log file.
# ----------------------------------------------------------------------------

proc debug_log_params {name} {

	set debug_log_level 30

	upvar 1 in_date_lo       l_in_date_lo
	upvar 1 in_date_hi       l_in_date_hi
	upvar 1 in_date_sel      l_in_date_sel
	upvar 1 in_ev_category   l_in_ev_category
	upvar 1 in_ev_class_id   l_in_ev_class_id
	upvar 1 in_ev_class_name l_in_ev_class_name
	upvar 1 in_ev_type_id    l_in_ev_type_id
	upvar 1 in_ev_type_name  l_in_ev_type_name
	upvar 1 in_ev_id         l_in_ev_id
	upvar 1 in_ev_name       l_in_ev_name
	upvar 1 in_start_time    l_in_start_time
	upvar 1 in_market_id     l_in_market_id
	upvar 1 in_market_name   l_in_market_name
	upvar 1 in_sel_id        l_in_sel_id
	upvar 1 in_sel_name      l_in_sel_name
	upvar 1 in_unstl_type    l_in_unstl_type
	upvar 1 in_bet_receipt   l_in_bet_receipt
	upvar 1 in_bet_id        l_in_bet_id


	OT_LogWrite $debug_log_level ">> ===================="
	OT_LogWrite $debug_log_level ">> Parameters for $name"
	OT_LogWrite $debug_log_level ">> ===================="

	if {[info exists  l_in_date_lo]}       { OT_LogWrite $debug_log_level ">> Date Lo     : $l_in_date_lo"
	}  else                                { OT_LogWrite $debug_log_level ">> Date Lo     : EMPTY" }

	if {[info exists  l_in_date_hi]}       { OT_LogWrite $debug_log_level ">> Date Hi     : $l_in_date_hi"
	} else                                 { OT_LogWrite $debug_log_level ">> Date Hi     : EMPTY" }

	if {[info exists  l_in_date_sel]}      { OT_LogWrite $debug_log_level ">> Date Sel    : $l_in_date_sel"
	} else                                 { OT_LogWrite $debug_log_level ">> Date Sel    : EMPTY" }

	if {[info exists  l_in_ev_category]}   { OT_LogWrite $debug_log_level ">> Category    : $l_in_ev_category"
	} else                                 { OT_LogWrite $debug_log_level ">> Category    : EMPTY" }

	if {[info exists  l_in_ev_class_id]}   { OT_LogWrite $debug_log_level ">> Class Id    : $l_in_ev_class_id"
	}  else                                { OT_LogWrite $debug_log_level ">> Class Id    : EMPTY" }

	if {[info exists  l_in_ev_class_name]} { OT_LogWrite $debug_log_level ">> Class Name  : $l_in_ev_class_name"
	}  else                                { OT_LogWrite $debug_log_level ">> Class Name  : EMPTY" }

	if {[info exists  l_in_ev_type_id]}    { OT_LogWrite $debug_log_level ">> Type Id     : $l_in_ev_type_id"
	} else                                 { OT_LogWrite $debug_log_level ">> Type Id     : EMPTY" }

	if {[info exists  l_in_ev_type_name]}  { OT_LogWrite $debug_log_level ">> Type Name   : $l_in_ev_type_name"
	} else                                 { OT_LogWrite $debug_log_level ">> Type Name   : EMPTY" }

	if {[info exists  l_in_ev_id]}         { OT_LogWrite $debug_log_level ">> Event Id    : $l_in_ev_id"
	} else                                 { OT_LogWrite $debug_log_level ">> Event Id    : EMPTY" }

	if {[info exists  l_in_ev_name]}       { OT_LogWrite $debug_log_level ">> Event Name  : $l_in_ev_name"
	} else                                 { OT_LogWrite $debug_log_level ">> Event Name  : EMPTY" }

	if {[info exists  l_in_start_time]}    { OT_LogWrite $debug_log_level ">> Start Time  : $l_in_start_time"
	} else                                 { OT_LogWrite $debug_log_level ">> Start Time  : EMPTY" }

	if {[info exists  l_in_market_id]}     { OT_LogWrite $debug_log_level ">> Market Id   : $l_in_market_id"
	} else                                 { OT_LogWrite $debug_log_level ">> Market Id   : EMPTY" }

	if {[info exists  l_in_market_name]}   { OT_LogWrite $debug_log_level ">> Market Name : $l_in_market_name"
	} else                                 { OT_LogWrite $debug_log_level ">> Market Name : EMPTY" }

	if {[info exists  l_in_unstl_type]}    { OT_LogWrite $debug_log_level ">> Unstl Type  : $l_in_unstl_type"
	} else                                 { OT_LogWrite $debug_log_level ">> Unstl Type  : EMPTY" }

	if {[info exists  l_in_sel_id]}        { OT_LogWrite $debug_log_level ">> Selc Id     : $l_in_sel_id"
	} else                                 { OT_LogWrite $debug_log_level ">> Selc Id     : EMPTY" }

	if {[info exists  l_in_sel_name]}      { OT_LogWrite $debug_log_level ">> Selc Name   : $l_in_sel_name"
	} else                                 { OT_LogWrite $debug_log_level ">> Selc Name   : EMPTY" }

	if {[info exists  l_in_bet_receipt]}   { OT_LogWrite $debug_log_level ">> Bet Receipt : $l_in_bet_receipt"}
	if {[info exists  l_in_bet_id]}        { OT_LogWrite $debug_log_level ">> Bet Id      : $l_in_bet_id"}


	OT_LogWrite $debug_log_level ">> ===================="

}

}
