# ==============================================================
# $Id: fb_charts.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::FBCHARTS {

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
		set FB_CHART_MAP(HF,$flag) [lindex $d 2]
		incr i
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
proc fb_read_wdw {ev_mkt_id {mkt_sort ""}} {

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
			tEv e,
			tEvMkt m,
			tEvOc s
		where
			m.ev_mkt_id = ? and
			m.ev_id = e.ev_id and
			c.ev_class_id = e.ev_class_id and
			s.ev_mkt_id = m.ev_mkt_id and
			s.fb_result <> '-'
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $ev_mkt_id]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]

	if {$rows != 3} {
		db_close $res
		error "expected three rows in this win/draw/win market"
	}

	## quatro markets dont need the domain set...
	## everything else does
	if {[db_get_col $res 0 fb_dom_int] == "-" && $mkt_sort != "QR"} {
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
proc fb_setup_mkt_CS {ev_id ev_mkt_id wdw_ev_mkt_id {action "INSERT"} {update_deriving_mkt 0 } } {

	global DB WDW USERNAME FB_CHART_MAP

	fb_read_wdw $wdw_ev_mkt_id

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

		for {set r 0} {$r < $rows} {incr r} {

			set sort_ord [db_get_col $res $r sort_ord]
			set sort     [db_get_col $res $r sort]
			set score_h  [db_get_col $res $r score_h]
			set score_a  [db_get_col $res $r score_a]
			set p_num    [db_get_col $res $r price_num]
			set p_den    [db_get_col $res $r price_den]
			set desc     [db_get_col $res $r desc]

			# CONTROL_CS: PremierBet; correct scores up to 5-1 each side only
			if {[OT_CfgGet CONTROL_CS "N"] == "Y"} {
				if { $score_h < 5 || ( $score_h == 5 && $score_a < 2) } {
					set CS($result,$sort_ord,$sort,$score_h,$score_a,$desc)\
						[list $p_num $p_den]
				}
			} else {
				set CS($result,$sort_ord,$sort,$score_h,$score_a,$desc)\
					[list $p_num $p_den]
			}
		}

		db_close $res
	}

	inf_close_stmt $stmt_q

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

	set sql_u {
		execute procedure pUpdEvOcPrice(
			p_adminuser = ?,
			p_ev_oc_id = ?,
			p_price_num = ?,
			p_price_den = ?
		)
	}

	if {[OT_CfgGet FUNC_GEN_OC_CODE 0]} {
		set gen_code Y
	} else {
		set gen_code N
	}

	set stmt_i [inf_prep_sql $DB $sql_i]
	set stmt_u [inf_prep_sql $DB $sql_u]

	set disp_base 0

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

	#
	# Get the selection description templates for this market sort
	#
	set templates [ADMIN::MKTPROPS::mkt_flag $class_sort CS desc ""]
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
				set DESC [lindex $p 5]

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
					set shortcut [ADMIN::AUTOGEN::SHORTCUT::shortcut\
							CS $result $sort $s1 $s2]
				}]} {
					set shortcut ""
				}

				set price_num [lindex $CS($s) 0]
				set price_den [lindex $CS($s) 1]

				if {$action=="INSERT"} {
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
				} elseif {$action=="UPDATE"} {
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
				} else {
					inf_close_stmt $stmt_i
					inf_close_stmt $stmt_u
					error "Unknown action -$action-"
				}
			}
			incr disp_base 1000
		}

		if {$update_deriving_mkt} {
			fb_update_deriving_mkt_info $ev_mkt_id $wdw_ev_mkt_id
		}


	} msg]

	inf_close_stmt $stmt_i
	inf_close_stmt $stmt_u

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

	if {$c} {
		error $msg
	}
}

#
# ----------------------------------------------------------------------------
# Generate quatro selections
# ----------------------------------------------------------------------------
#
proc fb_setup_mkt_QR {ev_id ev_mkt_id wdw_ev_mkt_id {fave_overide ""} {upd_deriving_mkt 0} } {
	global DB WDW USERNAME

	array set FB_RESULT [list AW3 1 AW2 2 HW3 3 HW2 4 AWD3 5 AWD2 6 HWD3 7 HWD2 8]

	array set FB_DESC   [list W3  "to win and 3 or more goals scored"\
							  W2  "to win and 2 or less goals scored"\
							  WD3 "to win or draw and 3 or more goals scored"\
							  WD2 "to win or draw and 2 or less goals scored"]

	fb_read_wdw $wdw_ev_mkt_id QR

	## calculate fave
	if {$fave_overide!=""} {
		set fave $fave_overide
	} else {
		set p_home [expr {1.0+$WDW(H,lp_num)/double($WDW(H,lp_den))}]
		set p_away [expr {1.0+$WDW(A,lp_num)/double($WDW(A,lp_den))}]

		if {$p_home <= $p_away} {
			set fave "H"
		} else {
			set fave "A"
		}
	}

	if {$fave == "H"} {
		set results {HW3 HW2 AWD3 AWD2}
	} else {
		set results {AW3 AW2 HWD3 HWD2}
	}

	set sql [subst {
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

	set stmt [inf_prep_sql $DB $sql]

	set DISPORDER 0

	foreach result $results {

		set fb_result $FB_RESULT($result)

		incr DISPORDER 10

		set desc $FB_DESC([string range $result 1 [string length $result]])
		set desc "$WDW([string range $result 0 0],desc) |${desc}|"

		set res [inf_exec_stmt $stmt\
			$USERNAME\
			$ev_mkt_id\
			$ev_id\
			$desc\
			$DISPORDER\
			1\
			100\
			$fb_result\
			$gen_code]

		db_close $res

	}

	inf_close_stmt $stmt

	if {$upd_deriving_mkt} {
		fb_update_deriving_mkt_info $ev_mkt_id $wdw_ev_mkt_id
	}
}

#
# ----------------------------------------------------------------------------
# Generate halp-time/full-time selections - there are (currently) two
# different chart styles:
#   - Style 1 determines which team is the favourite, and then uses that
#     team's price to generate the HT/FT prices.
#   - Style 2 doesn't care who is the favourite, and takes all the prices
#    (Home win, Draw, Away win) into account when generating the HT/FT prices.
# If action="INSERT" then attempt to insert new selections.
# If action="UPDATE" then update the existing selections.
# ----------------------------------------------------------------------------
#
proc fb_setup_mkt_HF {ev_id ev_mkt_id wdw_ev_mkt_id {action "INSERT"} {upd_deriving_mkt 0}} {

	set HF_MKT_STYLE [OT_CfgGet HF_MKT_STYLE 1]

	eval [fb_setup_mkt_HF_$HF_MKT_STYLE $ev_id $ev_mkt_id $wdw_ev_mkt_id $action]

	if {$upd_deriving_mkt} {
		fb_update_deriving_mkt_info $ev_mkt_id $wdw_ev_mkt_id
	}

}


#
# ----------------------------------------------------------------------------
# Style 1
# ----------------------------------------------------------------------------
#
proc fb_setup_mkt_HF_1 {ev_id ev_mkt_id wdw_ev_mkt_id action} {

	global DB WDW USERNAME FB_CHART_MAP

	array set FB_RESULT [list HH 1 HD 2 HA 3 DH 4 DD 5 DA 6 AH 7 AD 8 AA 9]

	fb_read_wdw $wdw_ev_mkt_id

	set DI $FB_CHART_MAP(CS,$WDW(H,fb_dom_int))

	# which team is favourite (home/away)

	set p_home [expr {1.0+$WDW(H,lp_num)/double($WDW(H,lp_den))}]
	set p_away [expr {1.0+$WDW(A,lp_num)/double($WDW(A,lp_den))}]

	if {$p_home <= $p_away} {
		set TY H
		set TP $p_home
	} else {
		set TY A
		set TP $p_away
	}

	set TP [format %0.3f $TP]

	set sql_q [subst {
		select
			result,price_num,price_den
		from
			tFBMktHF
		where
			domain = '$DI' and
			type   = '$TY' and
			team_price_lo < $TP and team_price_hi >= $TP
	}]

	set stmt_q [inf_prep_sql $DB $sql_q]
	set res    [inf_exec_stmt $stmt_q]
	inf_close_stmt $stmt_q

	set n_rows [db_get_nrows $res]

	if {$n_rows != 9} {
		db_close $res
		error "failed to read HF prices - check W/D/W market"
	}

	for {set r 0} {$r < $n_rows} {incr r} {
		set result  [db_get_col $res $r result]
		set p_num   [db_get_col $res $r price_num]
		set p_den   [db_get_col $res $r price_den]

		set HF($result) [list $p_num $p_den]
	}

	db_close $res

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

	set sql_u {
		execute procedure pUpdEvOcPrice(
			p_adminuser = ?,
			p_ev_oc_id = ?,
			p_price_num = ?,
			p_price_den = ?
		)
	}

	if {[OT_CfgGet FUNC_GEN_OC_CODE 0]} {
		set gen_code Y
	} else {
		set gen_code N
	}

	set stmt_i [inf_prep_sql $DB $sql_i]
	set stmt_u [inf_prep_sql $DB $sql_u]

	#
	# If we're doing updates rather than inserts then we need to
	# populate the lookup table so that we know which ev_oc_ids
	# to update.
	# We also want to count how many ev_ocs we updated.
	#
	if {$action=="UPDATE"} {
		ADMIN::FBCHARTS::fb_get_oc_lookup_info HF_OC_LOOKUP $ev_mkt_id
		set ev_oc_update_count 0
	}

	set DISPORDER 0

	foreach result {HH HD HA DH DD DA AH AD AA} {

		set r1 [string index $result 0]
		set r2 [string index $result 1]

		set fb_result $FB_RESULT($result)

		if {[catch {
			set shortcut [ADMIN::AUTOGEN::SHORTCUT::shortcut HF $fb_result]
		}]} {
			set shortcut ""
		}

		incr DISPORDER 10

		set price_num [lindex $HF($result) 0]
		set price_den [lindex $HF($result) 1]
		set desc "$WDW($r1,desc)/$WDW($r2,desc)"

		if {$action=="INSERT"} {
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

		} elseif {$action=="UPDATE"} {
			set log_msg ""
			# Find the ev_oc_id to update.
			# If it doesn't exist then do nothing.
			if {[catch {set ev_oc_id $HF_OC_LOOKUP(fb_result,$fb_result)}]} {
				append log_msg "No existing ev_oc_id found for " \
								"HF fb_result $fb_result. Skipping"
				ob::log::write INFO $log_msg
				ob::log::write DEBUG "Skipping $desc"
			} else {
				append log_msg "HF fb_result $fb_result; " \
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
		} else {
			inf_close_stmt $stmt_i
			inf_close_stmt $stmt_u
			error "Unknown action -$action-"
		}
	}
	inf_close_stmt $stmt_i
	inf_close_stmt $stmt_u

	#
	# If we're doing an update, give a warning message if we spotted that
	# some ev_ocs weren't updated (due to an asymmetrical tFBMktHF table).
	if {$action=="UPDATE"} {
		set ev_oc_exists_count [llength [array names HF_OC_LOOKUP fb_result*]]
		if {$ev_oc_update_count < $ev_oc_exists_count} {
			set log_msg "HF update - $ev_oc_exists_count evocs ; "
			append log_msg "only $ev_oc_update_count updated"
			ob::log::write INFO $log_msg
			set warn_msg "Some selections were not updated.  "
			append warn_msg "Please check your Correct Score and/or " \
							"Half Time/Full Time markets."
			msg_bind $warn_msg
		}
	}
}


#
# ----------------------------------------------------------------------------
# Style 2
# ----------------------------------------------------------------------------
#
proc fb_setup_mkt_HF_2 {ev_id ev_mkt_id wdw_ev_mkt_id action} {

	global DB WDW USERNAME FB_CHART_MAP

	array set FB_RESULT [list HH 1 HD 2 HA 3 DH 4 DD 5 DA 6 AH 7 AD 8 AA 9]

	fb_read_wdw $wdw_ev_mkt_id

	set DI $FB_CHART_MAP(HF,$WDW(H,fb_dom_int))

	# which team is favourite (home/away)

	set TP_H [format %0.3f [expr {1.0+$WDW(H,lp_num)/double($WDW(H,lp_den))}]]
	set TP_D [format %0.3f [expr {1.0+$WDW(D,lp_num)/double($WDW(D,lp_den))}]]
	set TP_A [format %0.3f [expr {1.0+$WDW(A,lp_num)/double($WDW(A,lp_den))}]]

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

	if {$n_rows != 9} {
		db_close $res
		error "failed to read HF prices - check W/D/W market"
	}

	for {set r 0} {$r < $n_rows} {incr r} {
		set result  [db_get_col $res $r result]
		set p_num   [db_get_col $res $r price_num]
		set p_den   [db_get_col $res $r price_den]

		set HF($result) [list $p_num $p_den]
	}

	db_close $res

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

	set sql_u {
		execute procedure pUpdEvOcPrice(
			p_adminuser = ?,
			p_ev_oc_id = ?,
			p_price_num = ?,
			p_price_den = ?
		)
	}

	if {[OT_CfgGet FUNC_GEN_OC_CODE 0]} {
		set gen_code Y
	} else {
		set gen_code N
	}

	set stmt_i [inf_prep_sql $DB $sql_i]
	set stmt_u [inf_prep_sql $DB $sql_u]

	#
	# If we're doing updates rather than inserts then we need to
	# populate the lookup table so that we know which ev_oc_ids
	# to update.
	# We also want to count how many ev_ocs we updated.
	#
	if {$action=="UPDATE"} {
		ADMIN::FBCHARTS::fb_get_oc_lookup_info HF_OC_LOOKUP $ev_mkt_id
		set ev_oc_update_count 0
	}

	set DISPORDER 0

	foreach result {HH HD HA DH DD DA AH AD AA} {

		set r1 [string index $result 0]
		set r2 [string index $result 1]

		set fb_result $FB_RESULT($result)

		if {[catch {
			set shortcut [ADMIN::AUTOGEN::SHORTCUT::shortcut HF $fb_result]
		}]} {
			set shortcut ""
		}

		incr DISPORDER 10
		set DESC $WDW($r1,desc)/$WDW($r2,desc)

		incr DISPORDER 10

		set price_num [lindex $HF($result) 0]
		set price_den [lindex $HF($result) 1]
		set desc "$WDW($r1,desc)/$WDW($r2,desc)"

		if {$action=="INSERT"} {
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

		} elseif {$action=="UPDATE"} {
			set log_msg ""
			# Find the ev_oc_id to update.
			# If it doesn't exist then do nothing.
			if {[catch {set ev_oc_id $HF_OC_LOOKUP(fb_result,$fb_result)}]} {
				append log_msg "No existing ev_oc_id found for " \
								"HF fb_result $fb_result. Skipping"
				ob::log::write INFO $log_msg
				ob::log::write DEBUG "Skipping $desc"
			} else {
				append log_msg "HF fb_result $fb_result; " \
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
		} else {
			inf_close_stmt $stmt_i
			inf_close_stmt $stmt_u
			error "Unknown action -$action-"
		}
	}

	inf_close_stmt $stmt_i
	inf_close_stmt $stmt_u

	#
	# If we're doing an update, give a warning message if we spotted that
	# some ev_ocs weren't updated (due to an asymmetrical tFBMktHF table).
	if {$action=="UPDATE"} {
		set ev_oc_exists_count [llength [array names HF_OC_LOOKUP fb_result*]]
		if {$ev_oc_update_count < $ev_oc_exists_count} {
			set log_msg "HF update - $ev_oc_exists_count evocs ; "
			append log_msg "only $ev_oc_update_count updated"
			ob::log::write INFO $log_msg
			set warn_msg "Some selections were not updated.  "
			append warn_msg "Please check your Correct Score and/or " \
							"Half Time/Full Time markets."
			msg_bind $warn_msg
		}
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
		ob::log::write DEBUG "set OC_LOOKUP(fb_result,$fb_result) $ev_oc_id"
		set OC_LOOKUP(cs,$cs_home,$cs_away) $ev_oc_id
		ob::log::write DEBUG "set OC_LOOKUP(cs,$cs_home,$cs_away) $ev_oc_id"
	}

	db_close $res
}

# Update derived market info.
# wdw_ev_mkt_id - the id of the WDW market from which the market is derived
proc fb_update_deriving_mkt_info {ev_mkt_id wdw_ev_mkt_id } {

	global DB USERNAME

	set sql {

		execute procedure pUpdEvMkt
		(
		p_adminuser = ?,
		p_ev_mkt_id = ?,
		p_deriving_mkt_id = ?
		)

	}

	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt $USERNAME $ev_mkt_id $wdw_ev_mkt_id]
	inf_close_stmt $stmt

	db_close $res

}

}
