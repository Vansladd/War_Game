# ==============================================================
# $Id: fb_charts.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval OB_fbcharts {

	# -------------------------------------------------------------------
	# IMPORTANT :::: Any extra market that is being added here
	# should be added to the list in the autogen.tcl in the admin module
	# for the proc do_ev_add_FB
	# -------------------------------------------------------------------

#
# ----------------------------------------------------------------------------
# Read football CS/HF chart information
# ----------------------------------------------------------------------------
#
proc fb_read_chart_info args {

	global FB_CHART_MAP

	if {[info exists FB_CHART_MAP(done)]} {
		return
	}

	set tmp [OT_CfgGet FB_EV_CHART_MAP]
	set i 0

	foreach d $tmp {
		set flag [lindex $d 0]
		set FB_CHART_MAP($i,flag)  $flag
		set FB_CHART_MAP($i,name)  [lindex $d 3]
		set FB_CHART_MAP(CS,$flag) [lindex $d 1]
		set FB_CHART_MAP(SF,$flag) [lindex $d 1]
		set FB_CHART_MAP(HF,$flag) [lindex $d 1]
		set FB_CHART_MAP(HT,$flag) [lindex $d 1]
		set FB_CHART_MAP(TG,$flag) [lindex $d 1]
		set FB_CHART_MAP(OU,$flag) [lindex $d 1]
		set FB_CHART_MAP(DC,$flag) [lindex $d 1]
		incr i
	}

	#Total Goals
	set tg_domains [OT_CfgGet TG_CHART_DOMAINS ""]
	foreach d $tg_domains {
		set flag [lindex $d 0]
		set FB_CHART_MAP($i,flag)  $flag
		set FB_CHART_MAP($i,name)  [lindex $d 2]
		set FB_CHART_MAP(TG,$flag) [lindex $d 1]
	}

	set FB_CHART_MAP(num_domains) $i
	set FB_CHART_MAP(done) 1
}


#
# ----------------------------------------------------------------------------
# Read win/draw/win market - this market is used to drive prices from the
# correct-score and half-time/full-time charts
# ----------------------------------------------------------------------------
#
proc fb_read_wdw {ev_id} {

	global DB WDW

	set sql [subst {
		select
			c.sort csort,
			e.ev_id,
			e.fb_dom_int,
			m.ev_mkt_id,
			s.desc,
			s.lp_num,
			s.lp_den,
			s.fb_result
		from
			tEvClass c,
			tEvType  t,
			tEv      e,
			tEvMkt   m,
			tEvOc    s
		where
			e.ev_id       = ?             and
			e.ev_id       = m.ev_id       and
			m.sort        = 'MR'          and
			m.ev_mkt_id   = s.ev_mkt_id   and
			e.ev_type_id  = t.ev_type_id  and
			t.ev_class_id = c.ev_class_id and
			s.fb_result <> '-'
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $ev_id]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]

	if {$rows != 3} {
		db_close $res
		error "expected three rows in win/draw/win market"
	}

	## markets need the domain set...
	if {[db_get_col $res 0 fb_dom_int] == "-"} {
		db_close $res
		error "event chart indicator is not set"
	}

	set WDW(class_sort) [db_get_col $res 0 csort]

	for {set r 0} {$r < $rows} {incr r} {

		set v_fb_result [db_get_col $res $r fb_result]

		foreach v [db_get_colnames $res] {
			set WDW($v_fb_result,$v) [db_get_col $res $r $v]
		}
	}

	db_close $res
}


# dec2frac -- takes a decimal and returns it as a fraction
# be warned, it's pretty accurate, so give it at least 6dp
# if you've got a repeating decimal
# i.e. 0.1428 yields 357/2500 (spot on), and 0.142857 is 1/7
proc dec2frac {decimal} {

        # safety check
        if { [expr {abs($decimal - int($decimal))}] <= 0.000001 } {
                return [list [expr int($decimal)] 1]
        }

        # initialise
        set z(1) $decimal
        set d(0) 0
        set d(1) 1
        set n(1) 1
        set i 1
        set epsilon 0.000001

        # iterate
        while {[expr {abs(double($n($i)/$d($i)) - $decimal)}] > $epsilon} {
                set j $i
                incr i

                set z($i) [expr { double(1.0)/( $z($j) - int($z($j))) }]
                set d($i) [expr { double($d($j) * int($z($i))) + $d([expr {$j-1}])}]
                set n($i) [expr { round($decimal * $d($i)) }]
        }

        # inform
        set num [expr int($n($i))]
        set den [expr int($d($i))]

        return [list $num $den]
}


#
# ----------------------------------------------------------------------------
# Return numerator/denominator for a price, either decimal or fractional
# ----------------------------------------------------------------------------
#
proc get_price_parts prc {

        set prc [string trim $prc]

        set RX_FRAC {^([0-9]+)/([0-9]+)$}
        set RX_DEC  {^([0-9]+)(\.[0-9]*)?$}

        # call conversion algorithm
        if {[regexp $RX_DEC $prc all]} {
                return [dec2frac [expr {$prc - 1}]]
        }
        if {[regexp $RX_FRAC $prc all n d]} {
                return [list $n $d]
        }

        if {$prc != ""} {
                error "\'$prc\' is not a valid price"
        }

        return [list "" ""]
}


# ----------------------------------------------------------------------------
# Finds and returns the selection ids, old prices and selection names for the
# specified market as a list of 3 lists,
#     list 1 results and seln_ids:   1 hd_seln_id 2 ad_seln_id 3 ha_seln_id
#     list 2 results and old prices: 1 hd_price   2 ad_price   3 ha_price
#     list 3 results and seln names: 1 hd_name    2 ad_name    3 ha_name
# ----------------------------------------------------------------------------
proc get_selns {ev_mkt_id} {
	global DB

	set sql [subst {
		select
			ev_oc_id,
			fb_result,
			lp_num,
			lp_den,
			desc
		from
			tEvOc
		where
			ev_mkt_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
        if {[catch {set rs  [inf_exec_stmt $stmt $ev_mkt_id]} msg]} {
                ob::log::write ERROR {get_selns, get_selns: $msg}
                error {get_selns failed in proc get_selns}
                return
        }

        inf_close_stmt $stmt

	set num_rows   [db_get_nrows $rs]
	set results    [list]
	set prices     [list]
	set seln_names [list]

	for {set r 0} {$r < $num_rows} {incr r} {

		set ev_oc_id  [db_get_col $rs $r ev_oc_id]
		set fb_result [db_get_col $rs $r fb_result]
		set lp_num    [db_get_col $rs $r lp_num]
		set lp_den    [db_get_col $rs $r lp_den]
		set desc      [db_get_col $rs $r desc]

		lappend results    $fb_result $ev_oc_id
		lappend prices     $fb_result [list $lp_num $lp_den]
		lappend seln_names $fb_result $desc
	}

	db_close $rs

	return [list $results $prices $seln_names]
}


# ----------------------------------------------------------------------------
# Calculates and returns double chance odds as a list:
#     {HD hd_odds AD ad_odds HA ha_odds}
#
# Requires WDW array to have been populated with win-draw-win details
# for the specified event
# ----------------------------------------------------------------------------
proc calc_odds_DC {} {
	global WDW

	# wdw odds
	set p_home [expr {1.0+$WDW(H,lp_num)/double($WDW(H,lp_den))}]
	set p_away [expr {1.0+$WDW(A,lp_num)/double($WDW(A,lp_den))}]
	set p_draw [expr {1.0+$WDW(D,lp_num)/double($WDW(D,lp_den))}]

	# calculate wdw probabilities
	set prob_home [expr {1/double($p_home)}]
	set prob_away [expr {1/double($p_away)}]
	set prob_draw [expr {1/double($p_draw)}]

	# calculate double chance probabilities
	# home and draw
	set hd [expr {double($prob_home) + double($prob_draw)}]

	# away and draw
	set ad [expr {double($prob_away) + double($prob_draw)}]

	# home and away
	set ha [expr {double($prob_home) + double($prob_away)}]

	# convert to decimal odds
	set hd [expr {1/double($hd)}]
	set ad [expr {1/double($ad)}]
	set ha [expr {1/double($ha)}]

	OT_LogWrite 1 "calc_odds_DC home and draw: $hd"
	OT_LogWrite 1 "calc_odds_DC away and draw: $ad"
	OT_LogWrite 1 "calc_odds_DC home and away: $ha"

	return [list HD $hd HA $ha AD $ad]
}



# ----------------------------------------------------------------------------
# Update double chance market odds for the specified event.
# Updates the double chance odds if there is a double chance
# market for the specified event; does nothing otherwise
# ----------------------------------------------------------------------------
proc fb_update_mkt_odds_DC {ev_id ev_mkt_id} {
	global DB WDW USERNAME

	# populate WDW array with win-draw-win details
	read_wdw $ev_id DC

	array set FB_RESULT [list HD 1 HA 2 AD 3]

	# calculate the odds
	# (returned as a list: HD hd_odds AD ad_odds HA ha_odds)
	array set DC_ODDS [calc_odds_DC]

	# find the selection ids, old prices and selection names
	# (returned as a list of 3 lists,
	#     list 1 fb_results and seln_ids:   1 hd_seln_id 2 ad_seln_id 3 ha_seln_id
	#     list 2 fb_results and old prices: 1 hd_price   2 ad_price   3 ha_price
	#     list 3 fb_results and seln names: 1 hd_name    2 ad_name    3 ha_name
	# )
	set   seln_id_price_list [get_selns $ev_mkt_id]
	array set SELN_IDS       [lindex $seln_id_price_list 0]
	array set SELN_PRC       [lindex $seln_id_price_list 1]
	array set SELN_NAM       [lindex $seln_id_price_list 2]

	foreach result {HD HA AD} {

		# only continue if we have a selection id for this result
		if {[info exists SELN_IDS($FB_RESULT($result))]} {

			set ev_oc_id $SELN_IDS($FB_RESULT($result))
			set status   "A"
			set displayed "Y"
			set odds     $DC_ODDS($result)

			OT_LogWrite 1 "update_mkt_odds_DC odds: $odds"

			set odds_list [get_price_parts $odds]

			OT_LogWrite 1 "update_mkt_odds_DC odds(frac): $odds_list"

			# now some checks: if num/den < 1 this selection cannot be
		        # available as it would allow hedging against the bookmaker
		        # so we suspend it and don't display it.
			if {[expr {double([lindex $odds_list 0])/[lindex $odds_list 1]}] <= 1.00} {
				OT_LogWrite 5 "Result = $result: suspending selection"
                                set status "S"
                                set displayed "N"
			}

			# check whether prices have changed
			set old_prices_list $SELN_PRC($FB_RESULT($result))

			# if prices have changed then update selection
			if {$old_prices_list != $odds_list} {


				# execute query
				set sql [subst {
					execute procedure pUpdEvOc(
						p_adminuser = ?,
						p_ev_oc_id  = ?,
						p_displayed = ?,
						p_status    = ?,
						p_lp_num    = ?,
						p_lp_den    = ?
					)
				}]

				set stmt [inf_prep_sql $DB $sql]
			        if {[catch {set res [inf_exec_stmt $stmt $USERNAME $ev_oc_id $displayed $status [lindex $odds_list 0] [lindex $odds_list 1]]} msg]} {
			                ob::log::write ERROR {proc update_mkt_odds_DC, upd_ev_oc: $msg}
			                error {upd_ev_oc failed in proc update_mkt_odds_DC}
			                return
			        }

			        inf_close_stmt $stmt
				db_close $res
			}
		}
	}


	unset WDW FB_RESULT DC_ODDS SELN_IDS SELN_PRC SELN_NAM
}



#
#-----------------------------------------------------------------------------
# Generate a Double Chance Market
#-----------------------------------------------------------------------------
#
proc fb_setup_mkt_DC {ev_id ev_mkt_id} {

	OT_LogWrite 1 "Starting Autogen FB Market Double Chance"

	global DB WDW USERNAME

	set sql [subst {
		select
			ev_oc_id
		from
			tEvOc
		where
			ev_mkt_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set rs [inf_exec_stmt $stmt $ev_mkt_id]} msg]} {
		ob_log::write ERROR {Failed to lookup ev_oc : $msg}
		return
	} else {
		set nrows [db_get_nrows $rs]
		db_close $rs
	}

	inf_close_stmt $stmt

	# create the selns, if they do not exist
	if {$nrows == 0} {

		set sql_i [subst {
			execute procedure pInsEvOc(
				p_adminuser = ?,
				p_ev_mkt_id = ?,
				p_ev_id     = ?,
				p_desc      = ?,
				p_disporder = ?,
				p_lp_num    = ?,
				p_lp_den    = ?,
				p_fb_result = ?,
				p_gen_code  = ?,
				p_do_tran   = 'N'
			)
		}]

		if {[OT_CfgGet FUNC_GEN_OC_CODE 0]} {
			set gen_code Y
		} else {
			set gen_code N
		}

		set stmt_i [inf_prep_sql $DB $sql_i]

		# we have three selections for Double Chance: 1X, 12 and X2
		set Desc [list 1 "1X" 2 "12" 3 "X2"]

		# calculate the odds
		# (returned as a list: HD hd_odds AD ad_odds HA ha_odds)
		array set DC_ODDS [calc_odds_DC]

		foreach {result i} {HD 1 HA 2 AD 3} {
			set status($i) "A"
			set displayed($i) "Y"
			set odds $DC_ODDS($result)

			set odds_list [get_price_parts $odds]
			# and make the values accessible to the stored proc
			set lp($i,num) [lindex $odds_list 0]
			set lp($i,den) [lindex $odds_list 1]

			if {[expr {double($lp($i,num))/$lp($i,den)}] <= 1.00} {
				OT_LogWrite 5 "i = $i: suspending selection"
				set status($i) "S"
				set displayed($i) "N"
			}
		}

		set DISPORDER 0

		#
		# Now create the selections
		#
		foreach {fb_result desc} $Desc {

			incr DISPORDER 10

			set res [inf_exec_stmt $stmt_i\
				$USERNAME\
				$ev_mkt_id\
				$ev_id\
				$desc\
				$DISPORDER\
				$lp($fb_result,num)\
				$lp($fb_result,den)\
				$fb_result\
				$gen_code]

			db_close $res
		}

		inf_close_stmt $stmt_i

		return 0
	} else {
		# if the market already exists, then update the
		# prices for them
		fb_update_mkt_odds_DC $ev_id $ev_mkt_id
	}
}


# ----------------------------------------------------------------------------
# Calculates and returns half-time/full-time odds as an array:
#
# Requires WDW array to have been populated with win-draw-win details
# for the specified event
# ----------------------------------------------------------------------------
proc calc_odds_HF {HF} {

	global DB WDW FB_CHART_MAP

	upvar HF tmp

	set DI $FB_CHART_MAP(HF,$WDW(H,fb_dom_int))

	# which team is favourite (home/away)

	set TP_H [format %0.3f [expr {1.0+$WDW(H,lp_num)/double($WDW(H,lp_den))}]]
	set TP_D [format %0.3f [expr {1.0+$WDW(D,lp_num)/double($WDW(D,lp_den))}]]
	set TP_A [format %0.3f [expr {1.0+$WDW(A,lp_num)/double($WDW(A,lp_den))}]]

	OT_LogWrite 1 "searching for HF prices:"
	OT_LogWrite 1 "$DI  $TP_H $TP_D $TP_A"
	set sql_q [subst {
		select decode(result,'WW','HH','DW','DH','LW','AH') result,
			   price_num,price_den
		from   tFBMktHF_2
		where  domain = '$DI' and
			   team_price_lo < $TP_H and team_price_hi >= $TP_H and
			   result in ('WW','DW','LW')
		union all
		select decode(result,'WW','AA','DW','DA','LW','HA') result,
			   price_num,price_den
		from   tFBMktHF_2
		where  domain = '$DI' and
			   team_price_lo < $TP_A and team_price_hi >= $TP_A and
			   result in ('WW','DW','LW')
		union all
		select result,
			   price_num,price_den
		from   tFBMktHF_2
		where  domain = '$DI' and
			   team_price_lo < $TP_D and team_price_hi >= $TP_D and
			   result in ('HD','DD','AD')
		order by 1
	}]

	set stmt_q [inf_prep_sql $DB $sql_q]
	set res    [inf_exec_stmt $stmt_q]
	inf_close_stmt $stmt_q

	set n_rows [db_get_nrows $res]

	if {$n_rows == 0} {
		db_close $res
		err_bind "The HF Lookup table seems to be empty"
	} elseif {$n_rows != 9} {
		db_close $res
		err_bind "failed to read HF prices - check W/D/W market"
	}

	for {set r 0} {$r < $n_rows} {incr r} {
		set result  [db_get_col $res $r result]
		set p_num   [db_get_col $res $r price_num]
		set p_den   [db_get_col $res $r price_den]
		set tmp($result) [list $p_num $p_den]
		OT_LogWrite 1 "tmp($result)=$tmp($result)"
	}

	db_close $res
}


#
#-----------------------------------------------------------------------------
# Generate a Halftime/Fulltime Market
#-----------------------------------------------------------------------------
#
proc fb_setup_mkt_HF {ev_id ev_mkt_id} {

	global DB WDW USERNAME

	array set FB_RESULT [list HH 1 HD 2 HA 3 DH 4 DD 5 DA 6 AH 7 AD 8 AA 9]

	# this is not required as we are calling
	# it only once before generating the derived markets

	#fb_read_wdw $ev_id
	set sql [subst {
		select
			ev_oc_id
		from
			tEvOc
		where
			ev_mkt_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set rs [inf_exec_stmt $stmt $ev_mkt_id]} msg]} {
		ob_log::write ERROR {Failed to lookup ev_oc : $msg}
		return
	} else {
		set nrows [db_get_nrows $rs]
		db_close $rs
	}

	inf_close_stmt $stmt

	# create the selns, if they do not exist
	if {$nrows == 0} {

		# calculate the odds
		calc_odds_HF HF

		set sql_i [subst {
			execute procedure pInsEvOc(
				p_adminuser = ?,
				p_ev_mkt_id = ?,
				p_ev_id     = ?,
				p_desc      = ?,
				p_disporder = ?,
				p_lp_num    = ?,
				p_lp_den    = ?,
				p_fb_result = ?,
				p_shortcut  = ?,
				p_gen_code  = ?,
				p_do_tran   = 'N'
			)
		}]

		if {[OT_CfgGet FUNC_GEN_OC_CODE 0]} {
			set gen_code Y
		} else {
			set gen_code N
		}

		set stmt_i [inf_prep_sql $DB $sql_i]

		set DISPORDER 0

		foreach result {HH HD HA DH DD DA AH AD AA} {

			set r1 [string index $result 0]
			set r2 [string index $result 1]

			set fb_result $FB_RESULT($result)

			if {[catch {
			set shortcut [OB_fbcharts::SHORTCUT::shortcut HF $fb_result]
			}]} {
				set shortcut ""
			}

			incr DISPORDER 10

			set price_num [lindex $HF($result) 0]
			set price_den [lindex $HF($result) 1]
			set desc "$WDW($r1,desc)/$WDW($r2,desc)"

			set res [inf_exec_stmt $stmt_i\
				$USERNAME\
				$ev_mkt_id\
				$ev_id\
				$desc\
				$DISPORDER\
				$price_num\
				$price_den\
				$fb_result\
				$shortcut\
				$gen_code]

			db_close $res
		}
		inf_close_stmt $stmt_i

		return 0
	} else {
		# if the market already exists, then update the
		# prices for them
		#fb_update_mkt_odds_HF $ev_id $ev_mkt_id
	}

}



# ----------------------------------------------------------------------------
# Calculates and returns half-time odds as an array:
#
# Requires WDW array to have been populated with win-draw-win details
# for the specified event
# ----------------------------------------------------------------------------
proc calc_odds_HT {HT} {

	global DB WDW FB_CHART_MAP

	upvar HT tmp

	set DI $FB_CHART_MAP(HT,$WDW(H,fb_dom_int))

	set sql_q [subst {
		select
			result,price_num,price_den
		from
			tFBMktH1
		where
			domain = '$DI' and
			result = ? and
			team_price_lo < ? and team_price_hi >= ?
	}]

	set stmt_q [inf_prep_sql $DB $sql_q]

	foreach result {H D A} {
		set TP [expr {1.0+$WDW($result,lp_num)/double($WDW($result,lp_den))}]
		set TP [format %0.3f $TP]

		set res    [inf_exec_stmt $stmt_q $result $TP $TP]

		set n_rows [db_get_nrows $res]

		if {$n_rows == 0} {
			db_close $res
			err_bind "The HT Lookup table seems to be empty"
		} elseif {$n_rows != 1} {
			db_close $res
			err_bind "failed to read HT prices - check W/D/W market"
		}

		set result  [db_get_col $res 0 result]
		set p_num   [db_get_col $res 0 price_num]
		set p_den   [db_get_col $res 0 price_den]
		set tmp($result) [list $p_num $p_den]
		OT_LogWrite 1 "tmp($result)=$tmp($result)"

		db_close $res
	}

	inf_close_stmt $stmt_q
}


#
#-----------------------------------------------------------------------------
# Generate a Halftime Market
#-----------------------------------------------------------------------------
#
proc fb_setup_mkt_HT {ev_id ev_mkt_id} {

	global DB WDW USERNAME

	# this is not required as we are calling
	# it only once before generating the derived markets

	#fb_read_wdw $ev_id

	set sql [subst {
		select
			ev_oc_id
		from
			tEvOc
		where
			ev_mkt_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set rs [inf_exec_stmt $stmt $ev_mkt_id]} msg]} {
		ob_log::write ERROR {Failed to lookup ev_oc : $msg}
		return
	} else {
		set nrows [db_get_nrows $rs]
		db_close $rs
	}

	inf_close_stmt $stmt

	# create the selns, if they do not exist
	if {$nrows == 0} {

		# calculate the odds
		calc_odds_HT HT

		set sql_i [subst {
			execute procedure pInsEvOc(
				p_adminuser = ?,
				p_ev_mkt_id = ?,
				p_ev_id     = ?,
				p_desc      = ?,
				p_disporder = ?,
				p_lp_num    = ?,
				p_lp_den    = ?,
				p_fb_result = ?,
				p_shortcut  = ?,
				p_gen_code  = ?,
				p_do_tran   = 'N'
			)
		}]

		if {[OT_CfgGet FUNC_GEN_OC_CODE 0]} {
			set gen_code Y
		} else {
			set gen_code N
		}

		set stmt_i [inf_prep_sql $DB $sql_i]

		set DISPORDER 0

		foreach fb_result {H D A} {

			if {[catch {
			set shortcut [OB_fbcharts::SHORTCUT::shortcut HT $fb_result]
			}]} {
				set shortcut ""
			}

			incr DISPORDER 10

			set price_num [lindex $HT($fb_result) 0]
			set price_den [lindex $HT($fb_result) 1]
			set desc "$WDW($fb_result,desc)"

			set res [inf_exec_stmt $stmt_i\
				$USERNAME\
				$ev_mkt_id\
				$ev_id\
				$desc\
				$DISPORDER\
				$price_num\
				$price_den\
				$fb_result\
				$shortcut\
				$gen_code]

			db_close $res
		}
		inf_close_stmt $stmt_i

		return 0
	} else {
		# if the market already exists, then update the
		# prices for them
		#fb_update_mkt_odds_HT $ev_id $ev_mkt_id
	}

}



# ----------------------------------------------------------------------------
# Calculates and returns under over odds
#
# Requires WDW array to have been populated with win-draw-win details
# for the specified event
# ----------------------------------------------------------------------------
proc calc_odds_OU {OU} {

	global DB WDW FB_CHART_MAP

	upvar OU tmp

	# the tEvMktOU does not have the domain, se we need not
	# fetch it from the FB_CHART_MAP

	set TP [expr {1.0+$WDW(D,lp_num)/double($WDW(D,lp_den))}]
	set TP [format %0.3f $TP]
	OT_LogWrite 1 "searching for OU prices:"
	OT_LogWrite 1 "$TP"
	set sql_q [subst {
		select
			result,price_num,price_den
		from
			tFBMktOU
		where
			team_price_lo < $TP and team_price_hi >= $TP
	}]

	set stmt_q [inf_prep_sql $DB $sql_q]
	set res    [inf_exec_stmt $stmt_q]
	inf_close_stmt $stmt_q

	set n_rows [db_get_nrows $res]

	if {$n_rows == 0} {
		db_close $res
		err_bind "The OU Lookup table seems to be empty"
	}
	for {set r 0} {$r < $n_rows} {incr r} {
		set result  [db_get_col $res $r result]
		set p_num   [db_get_col $res $r price_num]
		set p_den   [db_get_col $res $r price_den]
		set tmp($result) [list $p_num $p_den]
		OT_LogWrite 1 "tmp($result)=$tmp($result)"
	}

	db_close $res
}



# ----------------------------------------------------------------------------
# Update double chance market odds for the specified event.
# Updates the double chance odds if there is a double chance
# market for the specified event; does nothing otherwise
# ----------------------------------------------------------------------------
proc fb_update_mkt_odds_OU {ev_id ev_mkt_id} {

	global DB WDW USERNAME

	# find the market details for the specified event and market sort
	set ev_mkt_id [find_ev_mkt_id $ev_id OU]

	# if there is not a double chance market for the specified event then return
	if {$ev_mkt_id == {}} {
		return
	}

	# populate WDW array with win-draw-win details
	read_wdw $ev_id OU

	array set FB_RESULT [list HD 1 HA 2 AD 3]

	# calculate the odds
	# (returned as a list: HD hd_odds AD ad_odds HA ha_odds)
	array set OU_ODDS [calc_odds_UO $ev_id]

	# find the selection ids, old prices and selection names
	# (returned as a list of 3 lists,
	#     list 1 fb_results and seln_ids:   1 hd_seln_id 2 ad_seln_id 3 ha_seln_id
	#     list 2 fb_results and old prices: 1 hd_price   2 ad_price   3 ha_price
	#     list 3 fb_results and seln names: 1 hd_name    2 ad_name    3 ha_name
	# )
	set   seln_id_price_list [get_selns $ev_mkt_id]
	array set SELN_IDS       [lindex $seln_id_price_list 0]
	array set SELN_PRC       [lindex $seln_id_price_list 1]
	array set SELN_NAM       [lindex $seln_id_price_list 2]

	foreach result {HD HA AD} {

		# only continue if we have a selection id for this result
		if {[info exists SELN_IDS($FB_RESULT($result))]} {

			set ev_oc_id $SELN_IDS($FB_RESULT($result))
			set status   "A"
			set displayed "Y"
			set odds     $UO_ODDS($result)

			OT_LogWrite 1 "update_mkt_odds_UO odds: $odds"

			set odds_list [get_price_parts $odds]

			OT_LogWrite 1 "update_mkt_odds_UO odds(frac): $odds_list"

			# now some checks: if num/den < 1 this selection cannot be
		        # available as it would allow hedging against the bookmaker
		        # so we suspend it and don't display it.
			if {[expr {double([lindex $odds_list 0])/[lindex $odds_list 1]}] <= 1.00} {
				OT_LogWrite 5 "Result = $result: suspending selection"
                                set status "S"
                                set displayed "N"
			}

			# check whether prices have changed
			set old_prices_list $SELN_PRC($FB_RESULT($result))

			# if prices have changed then update selection
			if {$old_prices_list != $odds_list} {


				# execute query
				set sql [subst {
					execute procedure pUpdEvOc(
						p_adminuser = ?,
						p_ev_oc_id  = ?,
						p_displayed = ?,
						p_status    = ?,
						p_lp_num    = ?,
						p_lp_den    = ?
					)
				}]

				set stmt [inf_prep_sql $DB $sql]
			        if {[catch {set res [inf_exec_stmt $stmt $USERNAME $ev_oc_id $displayed $status [lindex $odds_list 0] [lindex $odds_list 1]]} msg]} {
			                ob::log::write ERROR {proc update_mkt_odds_UO, upd_ev_oc: $msg}
			                error {upd_ev_oc failed in proc update_mkt_odds_UO}
			                return
			        }

			        inf_close_stmt $stmt
				db_close $res
			}
		}
	}


	unset WDW FB_RESULT UO_ODDS SELN_IDS SELN_PRC SELN_NAM
}


#
#-----------------------------------------------------------------------------
# Generate a Over / Under Market
#-----------------------------------------------------------------------------
#
proc fb_setup_mkt_OU {ev_id ev_mkt_id} {

	global DB WDW USERNAME

	# this is not required as we are calling
	# it only once before generating the derived markets

	#fb_read_wdw $ev_id

	set sql [subst {
		select
			ev_oc_id
		from
			tEvOc
		where
			ev_mkt_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set rs [inf_exec_stmt $stmt $ev_mkt_id]} msg]} {
		ob_log::write ERROR {Failed to lookup ev_oc : $msg}
		return
	} else {
		set nrows [db_get_nrows $rs]
		db_close $rs
	}

	inf_close_stmt $stmt

	# create the selns, if they do not exist
	if {$nrows == 0} {

		# calculate the odds
		calc_odds_OU OU

		set sql_i [subst {
			execute procedure pInsEvOc(
				p_adminuser = ?,
				p_ev_mkt_id = ?,
				p_ev_id     = ?,
				p_desc      = ?,
				p_disporder = ?,
				p_lp_num    = ?,
				p_lp_den    = ?,
				p_fb_result = ?,
				p_shortcut  = ?,
				p_gen_code  = ?,
				p_do_tran   = 'N'
			)
		}]

		if {[OT_CfgGet FUNC_GEN_OC_CODE 0]} {
			set gen_code Y
		} else {
			set gen_code N
		}

		set stmt_i [inf_prep_sql $DB $sql_i]

		set DISPORDER 0

		foreach seln_info [OB_mktprops::mkt_seln_info FB OU] {

			array set NV $seln_info

			set fb_result $NV(fb_result)
			set desc      $NV(desc)

			if {[catch {
			set shortcut [OB_fbcharts::SHORTCUT::shortcut OU $fb_result]
			}]} {
				set shortcut ""
			}

			#Need to remove the pipes if desc is translateable
			set exp {([^\|]*)\|([^\|]*)\|(.*)}
			regexp $exp $desc match head desc str

			incr DISPORDER 10
			set res [inf_exec_stmt $stmt_i\
				$USERNAME\
				$ev_mkt_id\
				$ev_id\
				$desc\
				$DISPORDER\
				[lindex $OU($fb_result) 0]\
				[lindex $OU($fb_result) 1]\
				$fb_result\
				[lindex [array get NV shortcut] 1]\
				$gen_code]

			db_close $res
		}
		inf_close_stmt $stmt_i

		return 0
	} else {
		# if the market already exists, then update the
		# prices for them
		#fb_update_mkt_odds_OU $ev_id $ev_mkt_id
	}
}


# ----------------------------------------------------------------------------
# Calculates and returns total goals odds
#
# Requires WDW array to have been populated with win-draw-win details
# for the specified event
# ----------------------------------------------------------------------------
proc calc_odds_TG {TG} {

	global DB WDW FB_CHART_MAP

	upvar TG tmp

	#lookup from Draw - TODO make configurable
	set DI $FB_CHART_MAP(TG,$WDW(H,fb_dom_int))
	set TY "D"
	set TP [expr {1.0+$WDW(D,lp_num)/double($WDW(D,lp_den))}]
	set TP [format %0.3f $TP]
	OT_LogWrite 1 "searching for TG prices:"
	OT_LogWrite 1 "$DI  $TY  $TP"
	set sql_q [subst {
		select
			result,price_num,price_den
		from
			tFBMktTG
		where
			domain = '$DI' and
			type   = '$TY' and
			team_price_lo < $TP and team_price_hi >= $TP
	}]

	set stmt_q [inf_prep_sql $DB $sql_q]
	set res    [inf_exec_stmt $stmt_q]
	inf_close_stmt $stmt_q

	set n_rows [db_get_nrows $res]

	if {$n_rows == 0} {
		db_close $res
		err_bind "The TG Lookup table seems to be empty"
	}
	for {set r 0} {$r < $n_rows} {incr r} {
		set result  [db_get_col $res $r result]
		set p_num   [db_get_col $res $r price_num]
		set p_den   [db_get_col $res $r price_den]
		set tmp($result) [list $p_num $p_den]
		OT_LogWrite 1 "tmp($result)=$tmp($result)"
	}

	db_close $res
}


#
#-----------------------------------------------------------------------------
# Generate a Total Goals Market
#-----------------------------------------------------------------------------
#
proc fb_setup_mkt_TG {ev_id ev_mkt_id} {

	global DB WDW USERNAME

	set sql [subst {
		select
			ev_oc_id
		from
			tEvOc
		where
			ev_mkt_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set rs [inf_exec_stmt $stmt $ev_mkt_id]} msg]} {
		ob_log::write ERROR {Failed to lookup ev_oc : $msg}
		return
	} else {
		set nrows [db_get_nrows $rs]
		db_close $rs
	}

	inf_close_stmt $stmt

	# create the selns, if they do not exist
	if {$nrows == 0} {

		# calculate the odds
		calc_odds_TG TG

		set sql_i [subst {
			execute procedure pInsEvOc(
				p_adminuser = ?,
				p_ev_mkt_id = ?,
				p_ev_id     = ?,
				p_desc      = ?,
				p_disporder = ?,
				p_lp_num    = ?,
				p_lp_den    = ?,
				p_fb_result = ?,
				p_cs_home   = ?,
				p_cs_away   = ?,
				p_shortcut  = ?,
				p_gen_code  = ?,
				p_do_tran   = 'N'
			)
		}]

		if {[OT_CfgGet FUNC_GEN_OC_CODE 0]} {
			set gen_code Y
		} else {
			set gen_code N
		}

		set stmt_i [inf_prep_sql $DB $sql_i]

		set DISPORDER 0

		foreach seln_info [OB_mktprops::mkt_seln_info FB TG] {

			array set NV $seln_info

			set fb_result $NV(fb_result)
			set desc      $NV(desc)

			if {[catch {
				set shortcut [OB_fbcharts::SHORTCUT::shortcut TG $fb_result]
			}]} {
				set shortcut ""
			}

			#Need to remove the pipes if desc is translateable
			set exp {([^\|]*)\|([^\|]*)\|(.*)}
			regexp $exp $desc match head desc str

			# if any selection is missed out in the config file#
			# is still present in the look-up table, then, that selection
			# must not be inserted
			if {[info exists TG($desc)]} {

				set price_num [lindex $TG($desc) 0]
				set price_den [lindex $TG($desc) 1]

				incr DISPORDER 10
				set res [inf_exec_stmt $stmt_i\
					$USERNAME\
					$ev_mkt_id\
					$ev_id\
					$desc\
					$DISPORDER\
					$price_num\
					$price_den\
					$fb_result\
					[lindex [array get NV cs_home] 1]\
					[lindex [array get NV cs_away] 1]\
					$shortcut\
					$gen_code]

				db_close $res
			}
		}
		inf_close_stmt $stmt_i

		return 0
	} else {
		# if the market already exists, then update the
		# prices for them
		#fb_update_mkt_odds_TG $ev_id $ev_mkt_id
	}
}



# ----------------------------------------------------------------------------
# Calculates and returns score first odds
#
# Requires WDW array to have been populated with win-draw-win details
# for the specified event
# ----------------------------------------------------------------------------
proc calc_odds_SF {SF} {

	global DB WDW FB_CHART_MAP

	upvar SF tmp

	#lookup from Draw - TODO make configurable
	set DI $FB_CHART_MAP(SF,$WDW(H,fb_dom_int))
	set TY "D"
	set TP [expr {1.0+$WDW(D,lp_num)/double($WDW(D,lp_den))}]
	set TP [format %0.3f $TP]

	set sql_q [subst {
		select
			result,price_num,price_den
		from
			tFBMktSF
		where
			domain = '$DI' and
			type   = '$TY' and
			team_price_lo < $TP and team_price_hi >= $TP
	}]

	set stmt_q [inf_prep_sql $DB $sql_q]

	foreach result {H A} {

		set TP [expr {1.0+$WDW($result,lp_num)/double($WDW($result,lp_den))}]
		set TP [format %0.3f $TP]

		set res    [inf_exec_stmt $stmt_q]

		set n_rows [db_get_nrows $res]

		if {$n_rows == 0} {
			db_close $res
			err_bind "The SF Lookup table seems to be empty"
		} elseif {$n_rows != 1} {
			db_close $res
			error "failed to read SF prices - check W/D/W market"
		}

		set result  [db_get_col $res 0 result]
		set p_num   [db_get_col $res 0 price_num]
		set p_den   [db_get_col $res 0 price_den]
		set tmp($result) [list $p_num $p_den]
		OT_LogWrite 1 "tmp($result)=$tmp($result)"

		db_close $res
	}

	inf_close_stmt $stmt_q
}



# ----------------------------------------------------------------------------
# Update double chance market odds for the specified event.
# Updates the double chance odds if there is a double chance
# market for the specified event; does nothing otherwise
# ----------------------------------------------------------------------------
proc fb_update_mkt_odds_SF {ev_id} {
	global DB WDW USERNAME

	# find the market details for the specified event and market sort
	set ev_mkt_id [find_ev_mkt_id $ev_id SF]

	# if there is not a double chance market for the specified event then return
	if {$ev_mkt_id == {}} {
		return
	}

	# populate WDW array with win-draw-win details
	read_wdw $ev_id SF

	# Changed to -- array set FB_RESULT [list HA 1]
	array set FB_RESULT [list HD 1 HA 2 AD 3]

	# calculate the odds
	# (returned as a list: HD hd_odds AD ad_odds HA ha_odds)
	array set SF_ODDS [calc_odds_SF $ev_id]

	# find the selection ids, old prices and selection names
	# (returned as a list of 3 lists,
	#     list 1 fb_results and seln_ids:   1 hd_seln_id 2 ad_seln_id 3 ha_seln_id
	#     list 2 fb_results and old prices: 1 hd_price   2 ad_price   3 ha_price
	#     list 3 fb_results and seln names: 1 hd_name    2 ad_name    3 ha_name
	# )
	set   seln_id_price_list [get_selns $ev_mkt_id]
	array set SELN_IDS       [lindex $seln_id_price_list 0]
	array set SELN_PRC       [lindex $seln_id_price_list 1]
	array set SELN_NAM       [lindex $seln_id_price_list 2]

	## -- Changed to -- foreach result {HA}
	foreach result {HD HA AD} {

		# only continue if we have a selection id for this result
		if {[info exists SELN_IDS($FB_RESULT($result))]} {

			set ev_oc_id $SELN_IDS($FB_RESULT($result))
			set status   "A"
			set displayed "Y"
			set odds     $SF_ODDS($result)

			OT_LogWrite 1 "update_mkt_odds_SF odds: $odds"

			set odds_list [get_price_parts $odds]

			OT_LogWrite 1 "update_mkt_odds_SF odds(frac): $odds_list"

			# now some checks: if num/den < 1 this selection cannot be
		        # available as it would allow hedging against the bookmaker
		        # so we suspend it and don't display it.
			if {[expr {double([lindex $odds_list 0])/[lindex $odds_list 1]}] <= 1.00} {
				OT_LogWrite 5 "Result = $result: suspending selection"
                                set status "S"
                                set displayed "N"
			}

			# check whether prices have changed
			set old_prices_list $SELN_PRC($FB_RESULT($result))

			# if prices have changed then update selection
			if {$old_prices_list != $odds_list} {


				# execute query
				set sql [subst {
					execute procedure pUpdEvOc(
						p_adminuser = ?,
						p_ev_oc_id  = ?,
						p_displayed = ?,
						p_status    = ?,
						p_lp_num    = ?,
						p_lp_den    = ?
					)
				}]

				set stmt [inf_prep_sql $DB $sql]
			        if {[catch {set res [inf_exec_stmt $stmt $USERNAME $ev_oc_id $displayed $status [lindex $odds_list 0] [lindex $odds_list 1]]} msg]} {
			                ob::log::write ERROR {proc update_mkt_odds_SF, upd_ev_oc: $msg}
			                error {upd_ev_oc failed in proc update_mkt_odds_SF}
			                return
			        }

			        inf_close_stmt $stmt
				db_close $res
			}
		}
	}


	unset WDW FB_RESULT SF_ODDS SELN_IDS SELN_PRC SELN_NAM
}


#
#-----------------------------------------------------------------------------
# Generate a side to Score First Market
#-----------------------------------------------------------------------------
#
proc fb_setup_mkt_SF {ev_id ev_mkt_id} {

	global DB WDW USERNAME

	set sql [subst {
		select
			ev_oc_id
		from
			tEvOc
		where
			ev_mkt_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set rs [inf_exec_stmt $stmt $ev_mkt_id]} msg]} {
		ob_log::write ERROR {Failed to lookup ev_oc : $msg}
		return
	} else {
		set nrows [db_get_nrows $rs]
		db_close $rs
	}

	inf_close_stmt $stmt

	# create the selns, if they do not exist
	if {$nrows == 0} {

		# calculate the odds
		calc_odds_SF SF

		set sql_i [subst {
			execute procedure pInsEvOc(
				p_adminuser = ?,
				p_ev_mkt_id = ?,
				p_ev_id     = ?,
				p_desc      = ?,
				p_disporder = ?,
				p_lp_num    = ?,
				p_lp_den    = ?,
				p_fb_result = ?,
				p_shortcut = ?,
				p_gen_code  = ?,
				p_do_tran   = 'N'
			)
		}]

		if {[OT_CfgGet FUNC_GEN_OC_CODE 0]} {
			set gen_code Y
		} else {
			set gen_code N
		}

		set stmt_i [inf_prep_sql $DB $sql_i]

		set DISPORDER 0

		foreach fb_result {H A} {

			if {[catch {
			set shortcut [OB_fbcharts::SHORTCUT::shortcut SF $fb_result]
			}]} {
				set shortcut ""
			}

			incr DISPORDER 10

			set price_num [lindex $SF($fb_result) 0]
			set price_den [lindex $SF($fb_result) 1]
			set desc "$WDW($fb_result,desc)"

			set res [inf_exec_stmt $stmt_i\
				$USERNAME\
				$ev_mkt_id\
				$ev_id\
				$desc\
				$DISPORDER\
				$price_num\
				$price_den\
				$fb_result\
				$shortcut\
				$gen_code]

			db_close $res
		}
		inf_close_stmt $stmt_i

		return 0
	} else {
		# if the market already exists, then update the
		# prices for them
		#fb_update_mkt_odds_SF $ev_id $ev_mkt_id
	}
}



# ----------------------------------------------------------------------------
# Calculates and returns double chance odds as a list:
#     {HD hd_odds AD ad_odds HA ha_odds}
#
# Requires WDW array to have been populated with win-draw-win details
# for the specified event
# ----------------------------------------------------------------------------
proc calc_odds_CS {CS} {

	global DB WDW FB_CHART_MAP

	upvar CS tmp

	#fb_read_wdw $ev_id

	set class_sort $WDW(class_sort)

	set DI $FB_CHART_MAP(CS,$WDW(H,fb_dom_int))

	set sql_q [subst {
		select
			case sort when 'S' then 1 else 2 end sort_ord,
			sort,
			score_h,score_a,price_num,price_den,desc
		from
			tFBMktCS
		where
			domain = ? and
			type   = ? and
			team_price_lo < ? and team_price_hi >= ?
		order by
			sort_ord,sort,score_h,score_a
	}]

	set stmt_q [inf_prep_sql $DB $sql_q]

	foreach result {H D A} TY {W D W} {

		set TP [expr {1.0+($WDW($result,lp_num)/double($WDW($result,lp_den)))}]
		set TP [format %0.3f $TP]

		set res [inf_exec_stmt $stmt_q $DI $TY $TP $TP]

		set rows [db_get_nrows $res]

		if {$rows == 0} {
			db_close $res
			err_bind "The CS Lookup table seems to be empty"
		}

		for {set r 0} {$r < $rows} {incr r} {

			set sort_ord [db_get_col $res $r sort_ord]
			set sort     [db_get_col $res $r sort]
			set score_h  [db_get_col $res $r score_h]
			set score_a  [db_get_col $res $r score_a]
			set p_num    [db_get_col $res $r price_num]
			set p_den    [db_get_col $res $r price_den]

			set tmp($result,$sort_ord,$sort,$score_h,$score_a)\
					[list $p_num $p_den]
		}

		db_close $res
	}

	inf_close_stmt $stmt_q
}



# ----------------------------------------------------------------------------
# Update double chance market odds for the specified event.
# Updates the double chance odds if there is a double chance
# market for the specified event; does nothing otherwise
# ----------------------------------------------------------------------------
proc fb_update_mkt_odds_CS {ev_id} {

	global DB WDW USERNAME

	set sql_u {
			execute procedure pUpdEvOcPrice(
				p_adminuser = ?,
				p_ev_oc_id = ?,
				p_price_num = ?,
				p_price_den = ?
			)
	}

	set stmt_u [inf_prep_sql $DB $sql_u]

	#
	# If we're doing updates rather than inserts then we need to
	# populate the lookup table so that we know which ev_oc_ids
	# to update.
	# We also want to count how many ev_ocs we updated.
	#
	if {$action=="UPDATE"} {
		ADMIN::FBCHARTS::fb_get_oc_lookup_info CS_OC_LOOKUP $ev_mkt_id
		set ev_oc_update_count 0
	}

	if {$action=="UPDATE"} {
		set log_msg ""
		# Find the ev_oc_id to update.
		# If it doesn't exist then do nothing.
		if {[catch {set ev_oc_id $CS_OC_LOOKUP(cs,$s1,$s2)}]} {
			append log_msg "No existing ev_oc_id found for " \
							"CS home,away scores $s1,$s2. Skipping"
			ob::log::write INFO $log_msg
			ob::log::write DEBUG "Skipping $desc"
		} else {
			append log_msg "CS home,away scores $s1,$s2; " \
							"ev_oc_id is $ev_oc_id; " \
							"price is $price_num/$price_den"
			ob::log::write INFO $log_msg
			ob::log::write DEBUG "Updating $desc"
			set res [inf_exec_stmt $stmt_u\
				$USERNAME\
				$ev_oc_id\
				$price_num\
				$price_den]
			db_close $res
			incr ev_oc_update_count
		}
	}

	#
	# If we're doing an update, give a warning message if we spotted that
	# some ev_ocs weren't updated (due to an asymmetrical tFBMktCS table).
	if {$action=="UPDATE"} {
		set ev_oc_exists_count [llength [array names CS_OC_LOOKUP cs*]]
		if {$ev_oc_update_count < $ev_oc_exists_count} {
			set log_msg "CS update - $ev_oc_exists_count evocs ; "
			append log_msg "only $ev_oc_update_count updated"
			ob::log::write INFO $log_msg
			set warn_msg "Some selections were not updated.  "
			append warn_msg "Please check your Correct Score and/or " \
							"Half Time/Full Time markets."
			msg_bind $warn_msg
		}
	}




	unset WDW FB_RESULT CS_ODDS SELN_IDS SELN_PRC SELN_NAM
}


#
# ----------------------------------------------------------------------------
# Generate correct score selections
#
# If action="INSERT" then attempt to insert new selections.
# If action="UPDATE" then update the existing selections.
#
# When updating existing selections, some selections may be
# skipped if the tFBMktCS lookup table is not symmetrical.
# Similarly, some score combinations could be skipped if the
# corresponding selections weren't set up when the market
# selections were originally auto-generated.
# ----------------------------------------------------------------------------
#
proc fb_setup_mkt_CS {ev_id ev_mkt_id} {

	global DB WDW USERNAME

	set class_sort $WDW(class_sort)

	set sql [subst {
		select
			ev_oc_id
		from
			tEvOc
		where
			ev_mkt_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set rs [inf_exec_stmt $stmt $ev_mkt_id]} msg]} {
		ob_log::write ERROR {Failed to lookup ev_oc : $msg}
		return
	} else {
		set nrows [db_get_nrows $rs]
		db_close $rs
	}

	inf_close_stmt $stmt

	# create the selns, if they do not exist
	if {$nrows == 0} {

		# calculate the odds
		calc_odds_CS CS

		set sql_i [subst {
			execute procedure pInsEvOc(
				p_adminuser = ?,
				p_ev_mkt_id = ?,
				p_ev_id = ?,
				p_desc = ?,
				p_disporder = ?,
				p_lp_num = ?,
				p_lp_den = ?,
				p_fb_result = ?,
				p_cs_home = ?,
				p_cs_away = ?,
				p_shortcut = ?,
				p_gen_code = ?,
				p_do_tran = 'N'
			)
		}]

		if {[OT_CfgGet FUNC_GEN_OC_CODE 0]} {
			set gen_code Y
		} else {
			set gen_code N
		}

		set stmt_i [inf_prep_sql $DB $sql_i]

		set disp_base 0

		#
		# Get the selection description templates for this market sort
		#
		set templates [OB_mktprops::mkt_flag $class_sort CS desc ""]
		array set TMPL $templates

		set c [catch {

			foreach result {H D A} {

				set info     [lsort [array names CS $result,*]]
				set disp_add 0

				foreach s $info {

					incr disp_add 10

					set p    [split $s ,]
					set sort [lindex $p 2]

					#
					# These variables are set up to be used in the subst
					# command below
					#
					set TEAM $WDW($result,desc)
					set TS   [lindex $p 3]
					set OS   [lindex $p 4]

					if {$result == "H"} {
						set s1 $TS
						set s2 $OS
					} else {
						set s1 $OS
						set s2 $TS
					}

					#
					# Get the selection description template string for this
					# correct score sort
					#
					set template $TMPL($sort)

					#
					# Substitute in the values
					#
					set desc [subst -nocommands -nobackslashes $template]

					if {[catch {
						set shortcut [OB::FBCHARTS::SHORTCUT::shortcut\
								CS $result $sort $s1 $s2]
					}]} {
						set shortcut ""
					}

					set price_num [lindex $CS($s) 0]
					set price_den [lindex $CS($s) 1]

					set res [inf_exec_stmt $stmt_i\
						$USERNAME\
						$ev_mkt_id\
						$ev_id\
						$desc\
						[expr {$disp_base+$disp_add}]\
						$price_num\
						$price_den\
						$sort\
						$s1\
						$s2\
						$shortcut\
						$gen_code]
					db_close $res
				}
				incr disp_base 1000
			}
		} msg]

		inf_close_stmt $stmt_i

		if {$c} {
			error $msg
		} else {
			return 0
		}
	} else {
		# if the market already exists, then update the
		# prices for them
		#fb_update_mkt_odds_CS $ev_id $ev_mkt_id
	}
}


#
# ----------------------------------------------------------------------------
# Populate OC_LOOKUP array for a given ev_mkt_id
# to allow an ev_oc_id to be looked up via either:
#   fb_result          (for mkt_sort = 'HF')
#   cs_home,cs_away    (for mkt_sort = 'CS')
# ----------------------------------------------------------------------------
#
proc fb_get_oc_lookup_info {oc_lookup_array ev_mkt_id} {
	global DB
	upvar 1 $oc_lookup_array OC_LOOKUP

	set sql {
		select ev_oc_id,fb_result,cs_home,cs_away
		from tEvOc
		where ev_mkt_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt $ev_mkt_id]
	inf_close_stmt $stmt

	for {set row 0} {$row<[db_get_nrows $res]} {incr row} {
		set ev_oc_id [db_get_col $res $row ev_oc_id]
		set cs_home [db_get_col $res $row cs_home]
		set cs_away [db_get_col $res $row cs_away]
		set fb_result [db_get_col $res $row fb_result]
		set OC_LOOKUP(fb_result,$fb_result) $ev_oc_id
		set OC_LOOKUP($row,ev_oc_id) $ev_oc_id
		ob::log::write DEBUG "set OC_LOOKUP(fb_result,$fb_result) $ev_oc_id"
		set OC_LOOKUP(cs,$cs_home,$cs_away) $ev_oc_id
		ob::log::write DEBUG "set OC_LOOKUP(cs,$cs_home,$cs_away) $ev_oc_id"
	}

	set OC_LOOKUP(nrows) [db_get_nrows $res]

	db_close $res
}


#
# Update selection prices for other markets
#
proc fb_setup_other_markets {ev_id ev_mkt_id action} {

	global DB WDW USERNAME

	# This is not required since we are not applying
	# any calculation of the WDW prices to derive the price
	# for these mkts
	#fb_read_wdw $ev_id

	if {$action == "UPDATE"} {
		ADMIN::FBCHARTS::fb_get_oc_lookup_info OTHER_OC_LOOKUP $ev_mkt_id
	}

	set sql [subst {
		execute procedure pUpdEvOc(
			p_adminuser = ?,
			p_ev_oc_id  = ?,
			p_lp_num    = ?,
			p_lp_den    = ?,
			p_do_tran   = 'N'
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {$action == "UPDATE"} {
		for {set i 0} {$i < $OTHER_OC_LOOKUP(nrows)} {incr i} {
			if {[catch {set res [inf_exec_stmt $stmt\
				$USERNAME\
				$OTHER_OC_LOOKUP($i,ev_oc_id)\
				1\
				100000]} msg]} {
				ob::log::write ERROR "Failed to update selection $OTHER_OC_LOOKUP($i,ev_oc_id): $msg"
				error "Failed to update selection: $msg"
			}
			db_close $res
		}
	}

	inf_close_stmt $stmt
}


}
