# ==============================================================================
# $Id: stl-check.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# DESC: Will run settlement in a log only mode but with reseeded results.
#       This can be used to create manual adjustments csv's if a result has
#       been incorrectly entered and settled.
#
# MISC: Sets and uses the cookie STL_CHECK
# ==============================================================================

namespace eval ADMIN::SETTLE {

asSetAct ADMIN::SETTLE::GoSettleCheck  [namespace code go_settle_check]
asSetAct ADMIN::SETTLE::DoSettleCheck  [namespace code do_settle_check]
asSetAct ADMIN::SETTLE::DelSettleCheck [namespace code del_settle_check]

# Adds a selection to be reresulted
proc add_seln_stl_chk {} {
	_add_settle_check "O" [reqGetArg OcId]
}

# Adds a market to be reresulted
proc add_mkt_stl_chk {} {
	_add_settle_check "M" [reqGetArg MktId]
}

# Go to the reresulting page
#
# ARGS:
#   cookie_val:  Optional list of {type id type id ...}
#		to be used instead of cookie.
#   zero_custs:  Optional arg that indicates whether a previous
#		adjustment was made affected no customers
#
proc go_settle_check {{cookie_val NOT_SET} {bets -1}} {

	global DB
	global EVOC EVMKT TERMS

	set mkt_sql [subst {
		select
			m.ev_mkt_id,
			m.type,
			m.hcap_makeup,
			m.sort m_sort,
			m.ew_with_bet,
			m.ew_places,
			m.ew_fac_num,
			m.ew_fac_den,
			g.name,
			e.desc,
			e.start_time,
			c.sort c_sort
		from
			tEvClass c,
			tEvType t,
			tEvMkt m,
			tEv e,
			tEvOcGrp g
		where
				m.ev_mkt_id = ?
		and m.ev_id = e.ev_id
		and m.ev_oc_grp_id = g.ev_oc_grp_id
		and g.ev_type_id = t.ev_type_id
		and t.ev_class_id = c.ev_class_id
     	}]

	set rule4_sql [subst {
		select
			ev_mkt_rule4_id,
			market,
			time_from,
			time_to,
			deduction
		from
			tEvMktRule4
		where
			ev_mkt_id = ?
	}]

	set deadheat_ev_sql [subst {
		select
			e.ew_terms_id,
			e.ev_mkt_id,
			e.ew_fac_num,
			e.ew_fac_den,
			e.ew_places,
			d.dh_redn_id,
			d.ev_oc_id,
			d.dh_num,
			d.dh_den,
			d.dh_type
		from
			tEachWayTerms e,
			outer tDeadHeatRedn d
		where
			e.ev_mkt_id    = ?             and
			e.ew_terms_id  = d.ew_terms_id and
			d.ev_oc_id     = ?             and
			d.dh_type      = 'P'

		union

		select
			0,
			0,
			0,
			0,
			0,
			d.dh_redn_id,
			d.ev_oc_id,
			d.dh_num,
			d.dh_den,
			d.dh_type
		from
			 tDeadHeatRedn d
		where
			d.ev_oc_id       = ?    and
			d.ew_terms_id    is null
	}]

	set dividend_sql [subst {
		select
			div_id,
			type,
			nvl(seln_1,"n/a") seln_1,
			nvl(seln_2,"n/a") seln_2,
			nvl(seln_3,"n/a") seln_3,
			dividend
		from
			tDividend
		where
			ev_mkt_id = ?
	}]

	set seln_sql [subst {
		select
			o.ev_oc_id,
			o.result,
			o.place,
			o.desc oc_desc,
			o.fb_result s_sort,
			o.sp_num,
			o.sp_den,
			m.sort m_sort,
		 	m.ew_with_bet,
			m.ev_mkt_id,
			e.desc ev_desc,
			e.start_time,
			e.ev_id,
			c.sort c_sort
		from
			tEvOc o,
			tEvMkt m,
			tEv e,
			tEvType t,
			tEvClass c
		where
			ev_oc_id = ?
		and
			o.ev_mkt_id = m.ev_mkt_id
		and
			m.ev_id = e.ev_id
		and
			e.ev_type_id = t.ev_type_id
		and
			t.ev_class_id = c.ev_class_id
	}]

	set get_oc_sql [subst {
		select
			desc,
			ev_oc_id
		from
			tevoc
		where
			ev_mkt_id = ?
	}]

	set get_unstl_bets_for_mkt [subst {
		select
				count(*) as count
		from
				tEvoc oc,
				tOBet ob,
				tBet b
		where
				oc.ev_mkt_id = ? and
				oc.ev_oc_id = ob.ev_oc_id and
				ob.bet_id = b.bet_id and
				b.settled = 'N'
	}]

	set get_unstl_bets_for_oc [subst {
		select
				count(*) as count
		from
				tObet ob,
				tBet b
		where
				ob.ev_oc_id = ? and
				ob.bet_id = b.bet_id and
				b.settled = 'N'
	}]

	set check_list {}
	if {$cookie_val == "NOT_SET"} {
		#try to get it from the cookie
		set check_list [get_cookie STL_CHECK]
		OT_LogWrite 1 "getting info from cookie: $check_list"
	} else {
		set check_list $cookie_val
	}

	set ev_idx 0
	set mkt_idx 0
	foreach {t i} [split $check_list "|"] {

		ob::log::write DEBUG "*** $check_list $t $i"

		#for markets get rule4, dividends and market details
		if {$t == "M"} {
			OT_LogWrite 5 "-- add_settle_check: getting details for MKT $i"

			#market details
			set stmt [inf_prep_sql $DB $mkt_sql]
			set rs [inf_exec_stmt $stmt $i]
			inf_close_stmt $stmt

			set EVMKT($mkt_idx,ev_mkt_id) $i
			set EVMKT($mkt_idx,hcap_makeup) [db_get_col $rs 0 hcap_makeup]
			set EVMKT($mkt_idx,desc) [subst {[db_get_col $rs 0 start_time]\
				[db_get_col $rs 0 desc]\
				[db_get_col $rs 0 name]}]
			set EVMKT($mkt_idx,class_sort) [db_get_col $rs 0 c_sort]
			set EVMKT($mkt_idx,mkt_sort)   [db_get_col $rs 0 m_sort]
			set EVMKT($mkt_idx,is_ew)      [db_get_col $rs 0 ew_with_bet]
			set EVMKT($mkt_idx,ew_place)   [db_get_col $rs 0 ew_places]
			set EVMKT($mkt_idx,ew_num)     [db_get_col $rs 0 ew_fac_num]
			set EVMKT($mkt_idx,ew_den)     [db_get_col $rs 0 ew_fac_den]
 			db_close $rs

			#rule4 details
			set stmt [inf_prep_sql $DB $rule4_sql]
			set rs [inf_exec_stmt $stmt $i]
			inf_close_stmt $stmt

			set EVMKT($mkt_idx,num_rule_fours) [db_get_nrows $rs]

			for {set r4 0} {$r4 < [db_get_nrows $rs]} {incr r4} {
				set EVMKT($mkt_idx,$r4,ev_mkt_rule4_id)\
					[db_get_col $rs $r4 ev_mkt_rule4_id]
				set EVMKT($mkt_idx,$r4,market)\
					[db_get_col $rs $r4 market]
				set EVMKT($mkt_idx,$r4,time_from)\
					[db_get_col $rs $r4 time_from]
				set EVMKT($mkt_idx,$r4,time_to)\
					[db_get_col $rs $r4 time_to]
				set EVMKT($mkt_idx,$r4,deduction)\
					[db_get_col $rs $r4 deduction]
			}
			db_close $rs
			unset stmt rs



			# Get all the possible outcomes for the dividends
			set div 0
			set stmt [inf_prep_sql $DB $get_oc_sql]
			set rs   [inf_exec_stmt $stmt $i]
			inf_close_stmt $stmt

			set EVMKT($mkt_idx,num_ocs) [db_get_nrows $rs]

			for {set div_oc 0} {$div_oc < [db_get_nrows $rs]} {incr div_oc} {
					set EVMKT($mkt_idx,$div_oc,div_oc_desc)  [db_get_col $rs $div_oc desc]
					set EVMKT($mkt_idx,$div_oc,div_ev_oc_id) [db_get_col $rs $div_oc ev_oc_id]

					# Use 'desc' array as a mapping between the ev_oc_id & the outcome description
					set desc($EVMKT($mkt_idx,$div_oc,div_ev_oc_id)) $EVMKT($mkt_idx,$div_oc,div_oc_desc)
			}

			set desc(n/a) {n/a}

			db_close $rs
			unset stmt rs

			# Get dividend details for market
			set stmt [inf_prep_sql $DB $dividend_sql]
			set rs   [inf_exec_stmt $stmt $i]
			inf_close_stmt $stmt

			set EVMKT($mkt_idx,num_dividends) [db_get_nrows $rs]

				for {set div 0} {$div < [db_get_nrows $rs]} {incr div} {
					set EVMKT($mkt_idx,$div,ev_mkt_div_id) [db_get_col $rs $div div_id]
					set EVMKT($mkt_idx,$div,div_type)      [db_get_col $rs $div type]
					set EVMKT($mkt_idx,$div,div_seln1)     $desc([db_get_col $rs $div seln_1])
					set EVMKT($mkt_idx,$div,div_seln2)     $desc([db_get_col $rs $div seln_2])
					set EVMKT($mkt_idx,$div,div_seln3)     $desc([db_get_col $rs $div seln_3])
					set EVMKT($mkt_idx,$div,dividend)      [db_get_col $rs $div dividend]
			}
			db_close $rs
			unset stmt rs desc

			# get the number of unsettled bets for that market
			set stmt [inf_prep_sql $DB $get_unstl_bets_for_mkt]
			set rs   [inf_exec_stmt $stmt $i]
			inf_close_stmt $stmt

			set EVMKT($mkt_idx,num_unstl) [db_get_col $rs 0 count]

			db_close $rs
			unset stmt rs

			incr mkt_idx

				#for selections get selection details
		} elseif {$t == "O"} {
			OT_LogWrite 5 "-- add_settle_check: getting details for OC $i"
			set stmt [inf_prep_sql $DB $seln_sql]
			set rs [inf_exec_stmt $stmt $i]
			inf_close_stmt $stmt

			set nrows [db_get_nrows $rs]

			#TODO should check for 1 row - no errors
			if {$nrows == 1} {
				set EVOC($ev_idx,ev_oc_id) $i
				set EVOC($ev_idx,result) [db_get_col $rs 0 result]
				set EVOC($ev_idx,place) [db_get_col $rs 0 place]
				set EVOC($ev_idx,desc) [subst {[db_get_col $rs 0 start_time]\
					[db_get_col $rs 0 ev_desc]\
					[db_get_col $rs 0 oc_desc]}]

				set m_sort      [db_get_col $rs 0 m_sort]
				set c_sort      [db_get_col $rs 0 c_sort]
				set s_sort      [db_get_col $rs 0 s_sort]
				set ev_mkt_id   [db_get_col $rs 0 ev_mkt_id]
				set ew_with_bet [db_get_col $rs 0 ew_with_bet]

				# Bind the available result for the selection box
				bind_seln_results $ev_idx $c_sort $m_sort $s_sort

				# Get EachWayTerms

				set ev_mkt_id [db_get_col $rs 0 ev_mkt_id]

				set stmt       [inf_prep_sql $DB $deadheat_ev_sql]
				set res_seln   [inf_exec_stmt $stmt $ev_mkt_id $i $i]
				inf_close_stmt $stmt

				set nrows [db_get_nrows $res_seln]

				for {set r 0} {$r < $nrows} {incr r} {

					set dh_type      [db_get_col $res_seln $r dh_type]
					set ew_terms_id  [db_get_col $res_seln $r ew_terms_id]

					set EACHW($r,ev_oc_id)   [db_get_col $res_seln \
						$r ev_oc_id]
					set EACHW($r,ev_mkt_id)  [db_get_col $res_seln \
						$r ev_mkt_id]
					set EACHW($r,dh_redn_id) [db_get_col $res_seln \
						$r dh_redn_id]

					if {$dh_type == "P" && $ew_terms_id > 0} {

						set EACHW($r,ew_terms_id)  $ew_terms_id
						set EACHW($r,ew_fac_num) \
							[db_get_col $res_seln $r ew_fac_num]
						set EACHW($r,ew_fac_den) \
							[db_get_col $res_seln $r ew_fac_den]
						set EACHW($r,ew_places) \
							[db_get_col $res_seln $r ew_places]
						set EACHW($r,p_dh_num) \
							[db_get_col $res_seln $r dh_num]
						set EACHW($r,p_dh_den) \
							[db_get_col $res_seln $r dh_den]

						if {$EACHW($r,p_dh_num) != ""} {
							set p_dh_num($EACHW($r,ew_terms_id),$EACHW($r,ev_oc_id)) \
								$EACHW($r,p_dh_num)
							set p_dh_den($EACHW($r,ew_terms_id),$EACHW($r,ev_oc_id)) \
								$EACHW($r,p_dh_den)
						} else {
							set p_dh_num($EACHW($r,ew_terms_id),$EACHW($r,ev_oc_id)) 1
							set p_dh_den($EACHW($r,ew_terms_id),$EACHW($r,ev_oc_id)) 1
						}

						#
						# Build list of ew_terms.
						#
						set ew_term_ids($EACHW($r,ew_terms_id)) \
							"$EACHW($r,ew_places) \
							$EACHW($r,ew_fac_num) $EACHW($r,ew_fac_den)"

					} elseif {$dh_type == "P"} {
						set p_dh_num($EACHW($r,ev_oc_id)) \
							[db_get_col $res_seln $r dh_num]
						set p_dh_den($EACHW($r,ev_oc_id)) \
							[db_get_col $res_seln $r dh_den]
						tpSetVar HasPlaceDH 1
					} else {
						set w_dh_num($EACHW($r,ev_oc_id)) \
							[db_get_col $res_seln $r dh_num]
						set w_dh_den($EACHW($r,ev_oc_id)) \
							[db_get_col $res_seln $r dh_den]
						tpSetVar HasWinDH 1
					}

				}

				# Build list of ew_terms. HTML will loop through it and
				# try and get reductions for each event, if exists
				set l 0
				set EW_terms ""
				foreach ew_term_id [array names ew_term_ids] {
					set TERMS($l,ew_terms_id)      $ew_term_id
					set TERMS($l,ew_fac_num) \
						[lindex $ew_term_ids($ew_term_id) 1]
					set TERMS($l,ew_fac_den) \
						[lindex $ew_term_ids($ew_term_id) 2]
					set TERMS($l,ew_places) \
						[lindex $ew_term_ids($ew_term_id) 0]
					set EW_terms "$EW_terms $TERMS($l,ew_places),$TERMS($l,ew_fac_num),$TERMS($l,ew_fac_den)"
					incr l
				}
				ob::log::write DEBUG "*** Found $l TERMS"

				tpSetVar      NumTerms $l
				tpBindString  ColSpan [expr {$l + 8}]
				tpBindString  EW_terms $EW_terms
				tpBindVar TERMS_ew_terms_id TERMS ew_terms_id terms_idx
				tpBindVar TERMS_ew_fac_num  TERMS ew_fac_num  terms_idx
				tpBindVar TERMS_ew_fac_den  TERMS ew_fac_den  terms_idx
				tpBindVar TERMS_ew_places   TERMS ew_places   terms_idx

				db_close $res_seln

					set EVOC($ev_idx,sp)      "[db_get_col $rs 0 sp_num]/[db_get_col $rs 0 sp_den]"

					if {[string length $EVOC($ev_idx,sp)] == 1} {
				set EVOC($ev_idx,sp) {n/a}
					}

			 } else {
					ob::log::write ERROR { Exactly 1 row was not found for occassion $EVOC($ev_idx,desc) :$i}
					return;
			}
			db_close $rs
			unset stmt rs nrows

			# get the number of unsettled bets for this selection
			set stmt [inf_prep_sql $DB $get_unstl_bets_for_oc]
			set rs   [inf_exec_stmt $stmt $i]
			inf_close_stmt $stmt

			set EVOC($ev_idx,num_unstl) [db_get_col $rs 0 count]

			db_close $rs
			unset stmt rs

       			incr ev_idx
		}
	}

	#market bindings
	set EVMKT(num)  $mkt_idx

	if {!$bets} {
			tpSetVar NoBetsAffected 0
	} else {
			tpSetVar NoBetsAffected 1
	}

	tpBindVar MktId       EVMKT ev_mkt_id       mkt_idx
	tpBindVar HcapMakeup  EVMKT hcap_makeup     mkt_idx
	tpBindVar MktDesc     EVMKT desc	    mkt_idx
	tpBindVar MktEwPlace  EVMKT ew_place	mkt_idx
	tpBindVar MktEwNum    EVMKT ew_num	  mkt_idx
	tpBindVar MktEwDen    EVMKT ew_den	  mkt_idx
	tpBindVar MktNumUnStl EVMKT num_unstl       mkt_idx

 	tpBindVar Rule4Id     EVMKT ev_mkt_rule4_id mkt_idx r4_idx
	tpBindVar Type	EVMKT market	  mkt_idx r4_idx
	tpBindVar TimeFrom    EVMKT time_from       mkt_idx r4_idx
	tpBindVar TimeTo      EVMKT time_to	 mkt_idx r4_idx
	tpBindVar Deduction   EVMKT deduction       mkt_idx r4_idx

	tpBindVar DivId       EVMKT ev_mkt_div_id   mkt_idx div_idx
	tpBindVar DivType     EVMKT div_type	mkt_idx div_idx
	tpBindVar DivSeln1    EVMKT div_seln1       mkt_idx div_idx
	tpBindVar DivSeln2    EVMKT div_seln2       mkt_idx div_idx
	tpBindVar DivSeln3    EVMKT div_seln3       mkt_idx div_idx
	tpBindVar Dividend    EVMKT dividend	mkt_idx div_idx
	tpBindVar DivEvOcId   EVMKT div_ev_oc_id    mkt_idx div_oc_idx
	tpBindVar DivOcDesc   EVMKT div_oc_desc     mkt_idx div_oc_idx

	#outcome bindings
	set EVOC(num) $ev_idx

	tpBindVar OcId	EVOC ev_oc_id   oc_idx
	tpBindVar Result      EVOC result     oc_idx
	tpBindVar Place       EVOC place      oc_idx
	tpBindVar OcDesc      EVOC desc       oc_idx
	tpBindVar SP	  EVOC sp	 oc_idx
	tpBindVar OcNumUnStl  EVOC num_unstl  oc_idx

	asPlayFile settle_check.html

	array unset EVMKT
	array unset EVOC
}

# Runs through a dummy settlement with reseeded results
# Displays a csv at the end of customers that have had
# bets settled incorrectly
proc do_settle_check {} {

	global SELN_RESETTLE DB
	variable OVERRIDE
	variable SELN
	variable MKT

	array unset SELN
	array unset MKT
	array unset SELN_RESETTLE
	array unset OVERRIDE

	set check_ocs [list]
	set check_mkts [list]
	set bet_count 0

	for {set i 0} {$i < [reqGetNumVals]} {incr i} {
		set oc ""
		set mkt ""

		set name [reqGetNthName $i]
		if {[reqGetArg $name] == ""} {
			continue
		}

		set in [split $name "_"]

		switch -glob -- [lindex $in 0] {
			"result" {
				set oc [lindex $in 1]
				_add_res_override "O" $oc result [reqGetArg $name]
			}
			"place" {
				set oc [lindex $in 1]
				_add_res_override "O" $oc place [reqGetArg $name]
			}
			"wdh" {
				set oc [lindex $in 1]
				set price [split [reqGetArg $name] "/"]

				if {[string length $price] > 1} {
					_add_res_override "O" $oc w_dh_num [lindex $price 0]
					_add_res_override "O" $oc w_dh_den [lindex $price 1]
				}
			}
			"pdh" {
				set oc     [lindex $in 1]
				set ew_id  [lindex $in 2]
				set price  [split [reqGetArg $name] "/"]

				if {[string length $price] > 1} {
					_add_res_override "O" $oc p_dh_num [lindex $price 0] {rpl} {} $ew_id
					_add_res_override "O" $oc p_dh_den [lindex $price 1] {rpl} {} $ew_id
				}
			}
			"sp" {
				set oc [lindex $in 1]
				set price [split [reqGetArg $name] "/"]

				if {[string length $price] > 1} {
						_add_res_override "O" $oc sp_num [lindex $price 0]
						_add_res_override "O" $oc sp_den [lindex $price 1]
				}
			}
			"ew-place" {
				set mkt [lindex $in 1]
				_add_res_override "M" $mkt ew_places [reqGetArg $name]
			}
			"ew-price" {
				set mkt [lindex $in 1]
				set price [split [reqGetArg $name] "/"]

				if {[string length $price] > 1} {
						_add_res_override "M" $mkt ew_fac_num [lindex $price 0]
						_add_res_override "M" $mkt ew_fac_den [lindex $price 1]
				}
			}
			"r4-st" {
				set mkt    [lindex $in 1]
				set unique [lindex $in 2]
				set deduction [reqGetArg r4-deduction_${mkt}_$unique]

				# Prevent empty fields being added to the OVERRIDES array
				if {$deduction != ""} {
						set r4 \
					[list -1\
							 [reqGetArg r4-mkt_${mkt}_$unique]\
							 [reqGetArg $name]\
							 [reqGetArg r4-et_${mkt}_$unique]\
							 $deduction]
						_add_res_override "M" $mkt RULE4 $r4 add
				}
			}
			"rule4-del" {
				set mkt [lindex $in 1]
				set r4_id [lindex $in 2]
				_add_res_override "M" $mkt RULE4 $r4_id del 0
		 	}
			"hcap-makeup" {
				set mkt [lindex $in 1]
				_add_res_override "M" $mkt hcap_makeup [reqGetArg $name]
			}
			"dtype-mkt" {
				set mkt [lindex $in 1]
				set unique [lindex $in 2]
				set dividend  [reqGetArg dividend_${mkt}_$unique]

				# Prevent empty fields being added to the OVERRIDES array
				if {$dividend != ""} {
						set div \
					[list [reqGetArg $name]\
							  [reqGetArg div-seln0_${mkt}_$unique]\
							  [reqGetArg div-seln1_${mkt}_$unique]\
							  [reqGetArg div-seln2_${mkt}_$unique]\
							  $dividend]
						_add_res_override "M" $mkt DIV $div add
				}
			}
			"dtype-del" {
				set mkt [lindex $in 1]
				set div_id [lindex $in 2]
				_add_res_override "M" $mkt DIV $div_id del 0
		 	}
		}

		if {$mkt != ""} {
			#we'll just do settlement by selection so that we
			#dont duplicate any effort if selections and markets
			#are selected
			set sql {
				select
					ev_oc_id
				from
					tevoc
				where
					ev_mkt_id = ?
				and
					tevoc.settled = 'Y'
			}

			set stmt [inf_prep_sql $DB $sql]
			set rs [inf_exec_stmt $stmt $mkt]
			inf_close_stmt $stmt

			for {set m 0} {$m < [db_get_nrows $rs]} {incr m} {
				set ev_oc_id [db_get_col $rs $m ev_oc_id]

				set mkt_cr_after  [reqGetArg mkt-cr-after_${oc}]
				set mkt_stl_after [reqGetArg mkt-stl-after_${oc}]

				if {[lsearch -exact $check_ocs $ev_oc_id] == -1} {
						lappend check_ocs $ev_oc_id $mkt_cr_after $mkt_stl_after
				}

			}
			db_close $rs
		}

		if {$oc != "" && ([lsearch -exact $check_ocs $oc] == -1)} {
			set oc_cr_after  [reqGetArg oc-cr-after_${oc}]
			set oc_stl_after [reqGetArg oc-stl-after_${oc}]

			lappend check_ocs $oc $oc_cr_after $oc_stl_after
		}
	}

	foreach {oc cr_after stl_after} $check_ocs {
			_check_oc $oc $cr_after $stl_after
	}

	array unset OVERRIDE

	#play the page
	if {[array size SELN_RESETTLE] > 0} {
			# Get the customer's username who placed the affected bet
			set get_username {
				select
				  c.username,
				  r.lname,
				  a.ccy_code
				from
				  tCustomer c,
				  tCustomerReg r,
				  tAcct a,
				  tBet b
				where
				  c.cust_id = r.cust_id and
				  r.cust_id = a.cust_id and
				  a.acct_id = b.acct_id and
				  b.bet_id = ?
			}

			tpBufAddHdr "Content-type" "text/plain;"
			tpBufAddHdr "Content-disposition" "application;attachment; filename=ResettleEvent.txt"

			# First line of csv file gives a description of each column
			tpBufWrite "Description,Bet_id,Acct_id,Old Win lines,Old Lose lines,Old Void lines,Old Winnings, Old Refunds,New Win lines"
			tpBufWrite ",New Lose lines,New Void lines,New Winning,New Refund,Winnings diff,Refund diff,Manual Adjustment,Username,Surname,Currency\n"

			foreach nm [array names SELN_RESETTLE] {
		set stmt     [inf_prep_sql $DB $get_username]
		set rs       [inf_exec_stmt $stmt $nm]
		inf_close_stmt $stmt

		set username "[db_get_col $rs 0 username]"
		set lname    "[db_get_col $rs 0 lname]"
		set ccy_code [db_get_col $rs 0 ccy_code]

		tpBufWrite "$SELN_RESETTLE($nm),$username,$lname,$ccy_code\n"
		OT_LogWrite 3 "stl_check do_settle_check: $SELN_RESETTLE($nm),$username,$lname,$ccy_code"

		db_close $rs
		unset stmt rs username
			}

	} else {
			# Indicate when reloading page that zero results were returned
			go_settle_check [get_cookie STL_CHECK] 0
	}

	array unset SELN_RESETTLE
}


# Removes the item to be reresulted
proc del_settle_check {} {

	set check_list [get_cookie STL_CHECK]
	set type [reqGetArg type]
	set id [reqGetArg id]

	set new_cookie ""
	foreach {t i} [split $check_list "|"] {
		if {$t == $type && $i == $id} {
			continue
		}
		if {$new_cookie == ""} {
			set hdr ""
		} else {
			set hdr "|"
		}
		append new_cookie "$hdr${t}|${i}"
	}

	tpBufAddHdr "Set-Cookie" "STL_CHECK=$new_cookie"

	go_settle_check $new_cookie
}


# Add item to be reresulted
#
# ARGS:
#   level: M market O outcome
#   id:    ev_oc_id or ev_mkt_id depending on type
proc _add_settle_check {level id} {

	# we get together a list of items that we're interested
	# in changing in order to rerun settlement to see what happens
	# list of the form {TYPE|ID|TYPE|ID|...}
	# where TYPE=M market_id or O ev_oc_id

	set check_list [get_cookie STL_CHECK]

	if {$check_list == ""} {
		set cookie_hdr ""
	} else {
		set cookie_hdr "${check_list}|"
	}

	set add 1
	foreach {l i} [split $check_list "|"] {
		if {$l == $level && $i == $id} {
			set add 0
			break
		}
	}

	if {$add} {
		set cookie "${cookie_hdr}$level|$id"
		tpBufAddHdr "Set-Cookie" "STL_CHECK=${cookie_hdr}$level|$id"
	} else {
		set cookie $check_list
	}

	go_settle_check $cookie

}





# Checks to see if any items associated with this market
# or selection need to be reseeded with different results
# Should only be called when running a dummy settlment
#
# ARGS:
#   level: M Market O Outcome D Dead heat
#   id:    ev_oc_id or ev_mkt_id depending on type
proc _res_override_value {level id} {

	variable OVERRIDE
	variable DHEAT

	foreach nm [array names OVERRIDE] {
		OT_LogWrite 1 "jp: OVERRIDE(${nm}) = $OVERRIDE(${nm})"
	}

	if {$level == "M"} {
		upvar MKT local_array
	} elseif {$level == "O"} {
		upvar SELN local_array
	}

	if {[info exists OVERRIDE($level,$id,overrides)]} {
		foreach f $OVERRIDE($level,$id,overrides) {
			foreach {action val del_match ew_id} $OVERRIDE($level,$id,$f) {

				switch -- $action {
					"rpl" {
						# Set deadheat place reduction
						if {[regexp {^p_dh_(.+)$} $f all end]} {
							set F_prl [get_price_parts $val]
							set DHEAT(P,$id,$ew_id,dh_${end}) $val
							ob::log::write DEBUG "***NEW DEADHEAT ARGS $id \
								* $ew_id * place * $val"

						# Set deadheat win reduction
						} elseif {[regexp {^w_dh_(.+)$} $f all end]} {

							set DHEAT(W,$id,0,dh_${end}) $val
							ob::log::write DEBUG "***NEW DEADHEAT ARGS $id \
								* win * $val"
						} else {
							set local_array($id,$f) $val
						}
					}
					"add" {
						ob::log::write INFO {$local_array($id,$f) = $val}
						lappend local_array($id,$f) $val
					}
					"del" {
						set new_list [list]
						foreach l $local_array($id,$f) {
							if {[lindex $l $del_match] != $val} {
								lappend new_list $l
							}
						}
						set local_array($id,$f) $new_list
					}
				}

				# Perform for dividends only
				if {$f =={DIV} && $action != {del}} {
						set type     [lindex $val 0]
						set seln1    [lindex $val 1]
						set seln2    [lindex $val 2]
						set seln3    [lindex $val 3]
						set dividend [lindex $val 4]

						switch -- $type {
					TW -
					TP {
							set local_array($id,DIV,TP,$seln1) $dividend
					}
					FC {
							set local_array($id,DIV,FC,$seln1,$seln2) $dividend
							ob::log::write INFO {New FC div: local_array($id,$f) $val}
							ob::log::write INFO {New FC dividend: local_array($id,DIV,FC,$seln1,$seln2)=> $dividend}
					}
					TC {
							set local_array($id,DIV,TC,$seln1,$seln2,$seln3) $dividend
					}
					default {
							error "unexpected div type ($type): expected TW/TP/FC/TC"
					}
						}
				}
			}
		}
	}
}

# Adds the required reseed to the OVERRIDE array
#
# ARGS:
#   level:  M - market O - outcome
#   id:     ev_mkt_id for markets, ev_oc_id for outcomes
#   type:   Item being overriden should match items in
#	   stl_get_mkt_info and stl_get_seln_info ie:
#	   RULE4,result,hcap_makeup,place etc ...
#   val:    new value for type
#   action: rpl:       Replace val in DB with "val"
#	   add:       Add item to list of "type" ie:
#		      for rule4's or dividends where
#		      more than one can be associated
#		      with the market
#	   del:       Delete item from list where "del_match"
#		      index in the list matches val
#	   del_match: Which item in the list matching "val"
#		      should be deleted
proc _add_res_override {level id type val {action rpl} {del_match {}} {ew_id {}}} {
	variable OVERRIDE

	if {![info exists OVERRIDE($level,$id,overrides)] ||
		[lsearch -exact $OVERRIDE($level,$id,overrides) $type] == -1} {

		lappend OVERRIDE($level,$id,overrides) $type
	}

	lappend OVERRIDE($level,$id,$type) $action $val $del_match $ew_id

	ob::log::write DEBUG "New settler params: $OVERRIDE($level,$id,$type) $action $val $del_match $ew_id"
}

# Will run through a dummy settlement with the reseeded params
#
# ARGS:
#   ev_oc_id: outcome id
proc _check_oc {ev_oc_id cr_after stl_after} {
	variable STL_LOG_ONLY
	variable STL_BET_STATUS
	variable STL_DISP_LEVEL
	variable SELN_CHECK

	set STL_LOG_ONLY 1
	set STL_BET_STATUS "Y"
	set SELN_CHECK $ev_oc_id

	#we don't want logging to the screen as will be
	#producing csv file
	set STL_DISP_LEVEL 0
	stl_settle_seln $ev_oc_id 0 $cr_after $stl_after
	set STL_DISP_LEVEL [OT_CfgGet STL_DISP_LEVEL 5]
}

proc bind_seln_results {ev_id c_sort m_sort s_sort} {

	global EVOC

	array set RSLT_MAP [list - none V Void W Win L Lose H Handicap P Place U Push]
	#
	# Try to get selection-specific results list first - if not present,
	# fall back to the market results list
	#
	set flags [ADMIN::MKTPROPS::seln_flag $c_sort $m_sort $s_sort results]

	if {[llength $flags] == 0} {
		set flags [ADMIN::MKTPROPS::mkt_flag $c_sort $m_sort results]
	}

	set i 0

	if {[string first P $flags] >= 0 && ![info exists EVOC(display_place]} {
		set EVOC($ev_id,place_avail) 1
	} else {
		set EVOC($ev_id,place_avail) 0
	}

	# Diplay void only for AH/WH markets as hcap_makeup is settled at mkt level
	if {$m_sort == {AH} || $m_sort == {WH}} {
			set EVOC($ev_id,$i,flag) {V}
			set EVOC($ev_id,$i,name) {Void}
			incr i
	} else {
			foreach f [split $flags ""] {
		# Don't allow user to specify a 'none' result
		if {$f != {-}} {
				set EVOC($ev_id,$i,flag) $f
				set EVOC($ev_id,$i,name) $RSLT_MAP($f)
				incr i
		}
			}
	}

	tpBindVar ResultVal  EVOC flag oc_idx result_idx
	tpBindVar ResultDesc EVOC name oc_idx result_idx

	set EVOC($ev_id,numResult) $i
}


# close namespace
}

