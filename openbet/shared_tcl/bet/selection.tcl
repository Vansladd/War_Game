################################################################################
# $Id: selection.tcl,v 1.1 2011/10/04 12:26:11 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Handle selection details
#
# Configuration:
#    Does not read config file use ob_bet::init -[various options] to
#    customise
#
# Synopsis:
#    package require bet_bet ?4.5?
#
# Procedures:
#
#    ob_bet::verify_selns Verify chosen selections
#
################################################################################

namespace eval ob_bet {
	namespace export verify_selns

	# limited number of placeholders in selection queries
	variable MAX_SELN_PLACEHOLDERS
	variable VERIFY

	set MAX_SELN_PLACEHOLDERS 20
}



#API:verify_selns Verify price,hcap,status etc ... of selections in legs
#
#Usage:
#  ob_bet::verify_selns
#
# This should only be called once all the legs have been added.  There is
# no need to call this if the legs are being added to groups as it is
# implicitly called at this time
#
proc ob_bet::verify_selns {} {

	#log input params
	_log INFO "API(verify_selns)"

	if {[catch {
		set ret [eval _verify_selns]
	} msg]} {
		_err $msg
	}
	return $ret
}

#END OF API..... private procedures



# Prepare selection DB queries
#
proc ob_bet::_prepare_seln_qrys {} {

	ob_db::store_qry ob_bet::get_selns [subst {
		select
		  s.ev_oc_id,
		  NVL(ocv.price_num,s.lp_num)         as lp_num,
		  NVL(ocv.price_den,s.lp_den)         as lp_den,
		  NVL(NVL(s.sp_num_guide,s.lp_num),[_get_config dflt_sp_num_guide]) sp_num_guide,
		  NVL(NVL(s.sp_den_guide,s.lp_den),[_get_config dflt_sp_den_guide]) sp_den_guide,
		  s.fc_stk_limit,
		  s.tc_stk_limit,
		  s.desc oc_desc,
		  s.mult_key,
		  s.fb_result,
		  s.cs_home,
		  s.cs_away,
		  s.risk_info,
		  s.has_oc_variants,
		  s.fixed_stake_limits,
	      s.runner_num,
		  m.ev_mkt_id,
		  m.xmul,
		  m.fc_avail,
		  m.tc_avail,
		  m.sort mkt_sort,
		  NVL(ocv.type,m.type)                as mkt_type,
		  NVL(ocv.value,m.hcap_value)         as hcap_value,
		  m.bir_index,
		  NVL(m.bir_delay, NVL(e.bir_delay, NVL(t.bir_delay, NVL(c.bir_delay, NVL(ct.bir_delay, 0))))) as bir_delay,
		  m.lp_avail,
		  m.lp_exists,
		  m.sp_avail,
		  m.gp_avail,
		  NVL(s.acc_min, m.acc_min) as acc_min,
		  m.acc_max,
		  m.xmul,
		  m.ew_avail,
		  m.pl_avail,
		  m.pm_avail,
		  m.bet_in_run as in_running,
		  m.ep_active,
		  m.ew_fac_num,
		  m.ew_fac_den,
		  m.ew_places,
		  m.ew_with_bet,
		  m.is_ap_mkt,
		  m.hcap_precision,
		  m.stake_factor mkt_stk_factor,
		  g.ev_oc_grp_id,
		  m.name mkt_desc,
		  e.ev_type_id,
		  e.ev_id,
		  e.start_time,
		  e.sort ev_sort,
		  e.desc ev_desc,
		  e.mult_key ev_mult_key,
		  e.is_off,
		  e.flags,
		  e.suspend_at,
		  e.est_start_time,
		  decode(c.status||t.status||e.status||m.status||s.status||NVL(ocv.status,'A'),
		  'AAAAAA', 'A', 'S') status,
		  case
		  when (e.suspend_at is null
		        or e.suspend_at >= extend(current, year to second))
		  then 'N'
		  else 'Y' end ev_suspended,
		  case
		  when (NVL(e.off_time, e.start_time) >= extend(current, year to second))
		  then 'N'
		  else 'Y' end ev_started,
		  t.ev_class_id,
		  NVL(NVL(NVL(s.min_bet,m.min_bet), e.min_bet), t.ev_min_bet) min_bet,
		  NVL(NVL(NVL(NVL(ocv.max_bet,s.max_bet), m.max_bet), e.max_bet),t.ev_max_bet) max_bet,
		  NVL(NVL(NVL(s.sp_max_bet,m.sp_max_bet), e.sp_max_bet), t.sp_max_bet) max_sp_bet,
		  NVL(NVL(s.ep_max_bet,g.ep_max_bet), t.ep_max_bet) max_ep_bet,
		  NVL(NVL(s.max_place_lp, e.max_place_lp), t.ev_max_place_lp) max_place_lp,
		  NVL(NVL(s.max_place_sp, e.max_place_sp), t.ev_max_place_sp) max_place_sp,
		  NVL(NVL(s.max_place_ep, g.oc_max_place_ep), t.ev_max_place_ep) max_place_ep,
		  NVL(NVL(NVL(NVL(s.ew_factor,m.ew_factor),g.oc_ew_factor),e.ew_factor),1.00) ew_factor,
		  NVL(NVL(NVL(NVL(s.max_multiple_bet,
			m.max_multiple_bet),e.max_multiple_bet),
			g.max_multiple_bet),t.max_multiple_bet)
			as max_multiple_bet,
		  t.max_payout,
		  t.name type_desc,
		  t.flags ev_type_flags,
		  NVL(t.tolerance,c.tolerance) as tolerance,
		  c.sort class_sort,
		  c.name class_desc,
		  c.category,
		  ocv.oc_var_id,
		  r.name as region_desc
		from
		  tevoc               s,
		  tevmkt              m,
		  tevocgrp            g,
		  tev                 e,
		  tevtype             t,
		  tevclass            c,
		  outer tevocvariant  ocv,
		  outer tregion       r,
		  tevcategory         ct
		where
		  s.ev_oc_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) and
		  s.ev_mkt_id    = m.ev_mkt_id    and
		  m.ev_oc_grp_id = g.ev_oc_grp_id and
		  t.region_id    = r.region_id    and
		  m.ev_id        = e.ev_id        and
		  e.ev_type_id   = t.ev_type_id   and
		  t.ev_class_id  = c.ev_class_id  and
		  s.ev_oc_id     = ocv.ev_oc_id   and
		  m.ev_mkt_id    = ocv.ev_mkt_id  and
		  ct.category    = c.category     and
		  ocv.oc_var_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
	}]

	# EvOcVariants Available hcaps
	ob_db::store_qry ob_bet::get_evocvariant {
		SELECT
			oc_var_id
		FROM
			tEvOcVariant
		WHERE
			ev_oc_id = ?
		AND type      = 'HC'
		AND status    = 'A'
		AND displayed = 'Y'
		AND value     = ?
		AND ((apply_price = 'A' AND price_num = ? AND price_den = ?)
			OR (apply_price = 'R'))
	}

	ob_db::store_qry ob_bet::get_dynamic_stake_factors {
		select
			'CATEGORY' as level,
			s.ev_oc_id,
			e.start_time,
			sfp1.mins_before_from,
			sfp1.mins_before_to,
			sfp1.stake_factor
		from
			tEvOc s,
			tEv e,
			tEvClass c,
			tEvCategory y,
			tStkFacPrfLink sfl1,
			tStkFacPrfPeriod sfp1
		where
			s.ev_id = e.ev_id and
			e.ev_class_id = c.ev_class_id and
			c.category = y.category and
			y.ev_category_id = sfl1.id and
			sfl1.sf_prf_id = sfp1.sf_prf_id and
			sfl1.level = 'CATEGORY' and
			s.ev_oc_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
		union
		select
			'CLASS' as level,
			s.ev_oc_id,
			e.start_time,
			sfp2.mins_before_from,
			sfp2.mins_before_to,
			sfp2.stake_factor
		from
			tEvOc s,
			tEv e,
			tEvType t,
			tEvClass c,
			tStkFacPrfLink sfl2,
			tStkFacPrfPeriod sfp2
		where
			s.ev_id = e.ev_id and
			e.ev_type_id = t.ev_type_id and
			t.ev_class_id = c.ev_class_id and
			c.ev_class_id = sfl2.id and
			sfl2.sf_prf_id = sfp2.sf_prf_id and
			sfl2.level = 'CLASS' and
			s.ev_oc_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
		union
		select
			'TYPE' as level,
			s.ev_oc_id,
			e.start_time,
			sfp3.mins_before_from,
			sfp3.mins_before_to,
			sfp3.stake_factor
		from
			tEvOc s,
			tEv e,
			tEvType t,
			tEvClass c,
			tStkFacPrfLink sfl3,
			tStkFacPrfPeriod sfp3
		where
			s.ev_id = e.ev_id and
			e.ev_type_id = t.ev_type_id and
			t.ev_class_id = c.ev_class_id and
			t.ev_type_id = sfl3.id and
			sfl3.sf_prf_id = sfp3.sf_prf_id and
			sfl3.level = 'TYPE' and
			s.ev_oc_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
		union
		select
			'EVENT' as level,
			s.ev_oc_id,
			e.start_time,
			sfp4.mins_before_from,
			sfp4.mins_before_to,
			sfp4.stake_factor
		from
			tEvOc s,
			tEv e,
			tEvType t,
			tEvClass c,
			tStkFacPrfLink sfl4,
			tStkFacPrfPeriod sfp4
		where
			s.ev_id = e.ev_id and
			e.ev_type_id = t.ev_type_id and
			t.ev_class_id = c.ev_class_id and
			e.ev_id = sfl4.id and
			sfl4.sf_prf_id = sfp4.sf_prf_id and
			sfl4.level = 'EVENT' and
			s.ev_oc_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
		order by
			2,1,4 asc
	} 300
}



#  Check if the provided hcap price/value can be matched by an EvOcVariant
#
proc ob_bet::_verify_variants {} {

	variable SELN
	variable LEG

	set LEG(ocv_ids) [list]

	_log DEBUG "Verifying variants ..."

	if {[_get_config oc_variants]} {

		for {set l 0} {$l < $LEG(num)} {incr l} {
			if {
				$LEG($l,hcap_value) != "" &&
				![info exists LEG($l,ocv_id)]
			} {
				if {[catch {set rs [ob_db::exec_qry\
										ob_bet::get_evocvariant\
										$LEG($l,selns)\
										$LEG($l,hcap_value)\
										$LEG($l,lp_num)\
										$LEG($l,lp_den)]} msg]} {
					error "Unable to retrieve oc variants\
						from db: $msg\
						seln: $LEG($l,selns)\
						hcap_value: $LEG($l,hcap_value)\
						lp_num: $LEG($l,lp_num)\
						lp_den: $LEG($l,lp_den)"\
						""\
						SELN_INVALID_OC_VARIANT
				}

				set nrows [db_get_nrows $rs]

				if {$nrows == 1} {
					set ocv_id [db_get_col $rs 0 oc_var_id]
					set LEG($l,ocv_id) $ocv_id
					lappend LEG(ocv_ids) $ocv_id
				} elseif { $nrows > 1 } {
					error "Unable to retrieve oc variants\
						from db - more than 1 row: $msg\
						seln: $LEG($l,selns)\
						hcap_value: $LEG($l,hcap_value)\
						lp_num: $LEG($l,lp_num)\
						lp_den: $LEG($l,lp_den)"\
						""\
						SELN_INVALID_OC_VARIANT
				}
			} elseif {[info exists LEG($l,ocv_id)]} {
				lappend LEG(ocv_ids) $LEG($l,ocv_id)
			}
		}
	}
}



# Verify selection details
#
proc ob_bet::_verify_selns {} {

	variable SELN
	variable LEG
	variable VERIFY
	variable LEG_MAX_COMBI
	variable COMBI

	if {![_smart_reset VERIFY]} {
		# already verifyed the selections
		return
	}

	_smart_reset COMBI

	_get_selns
	_log INFO "Verifying selection details ..."

	for {set l 0} {$l < $LEG(num)} {incr l} {

		set selns $LEG($l,selns)
		foreach seln $selns {
			if {![info exists SELN(selns)] || [lsearch $SELN(selns) $seln] == -1} {
				error "Selection $seln does not exist in database"
			}
		}

		set check_price 1
		set LEG($l,best_price_change) 0

		# supply the leg sort if it hasn't been explicitly specifyed
		if {$LEG($l,leg_sort) == ""} {
			# should have already checked when adding the leg that this
			# isn't a complex leg
			set oc $LEG($l,selns)
			if {$SELN($oc,mkt_type) != "-"} {
				if {$SELN($oc,mkt_type) == "A"} {
					set leg_sort "AH"
				} else {
					set leg_sort $SELN($oc,mkt_sort)
				}
				# complex legs must be to-win
				# set BSEL($sk,ew_avail) N
				# set BSEL($sk,pl_avail) N
			} else {
				set leg_sort "--"
			}
			set LEG($l,leg_sort) $leg_sort
		} else {
			set leg_sort $LEG($l,leg_sort)
		}

		# check if the leg sort confines how the leg can be combined
		set LEG($l,can_combi) "Y"
		if {[info exists LEG_MAX_COMBI($leg_sort)]} {
			foreach {
				can_combi
				max_combi
				max_selns
			} $LEG_MAX_COMBI($leg_sort) {break}
			set LEG($l,can_combi) $can_combi

			if {$max_combi != ""} {
				set LEG($l,max_combi) $max_combi
			}
			if {$max_selns != ""} {
				set LEG($l,max_selns) $max_selns
			}
		} else {
			set LEG($l,max_combi) [_get_config max_mult_selns]
			set LEG($l,max_selns) [_get_config max_mult_selns]
		}
		set LEG($l,min_combi) 1

		# check selection can be combined
		::ob_bet::_log INFO "LEG $l - Checking selections can be combined"
		set selns $LEG($l,selns)
		if {[llength $selns] != 1} {
			# already checked the correct number of selections in add_leg
			# only need to check that the leg sort is available
			# and that all the selections are in the same market
			switch -- $LEG($l,leg_sort) {
				"SF" -
				"CF" -
				"RF" {
					set cast_check_col fc_avail
				}
				"TC" -
				"CT" {
					set cast_check_col tc_avail
				}
				default {
					set cast_check_col ""
				}
			}

			# Price of leg if LP were to be selected, or "" if impossible to
			# do so. Used to allow client to determine potential winnings w/o
			# going to the server when price type is changed.
			set LEG($l,pot_lp_num) ""
			set LEG($l,pot_lp_den) ""

			switch -- $LEG($l,leg_sort) {
				"SF" -
				"CF" -
				"RF" -
				"TC" -
				"CT" {
					set mkt $SELN([lindex $selns 0],ev_mkt_id)
					if {$SELN([lindex $selns 0],$cast_check_col) != "Y"} {
						_need_override LEG $l BAD_LEG_SORT
					}
					for {set s 0} {$s < [llength $selns]} {incr s} {
						# need to be in the same market
						if {$SELN([lindex $selns $s],ev_mkt_id) != $mkt} {
							set err "cant combine selns in $LEG($l,leg_sort) "
							append err "from diff mkts: $l"
							error\
								$err\
								""\
								SELN_INVALID_LEGS_IN_SORT
						}

						# can't combine unnamed favorites in *cast
						if {$SELN([lindex $selns $s],fb_result) != "-"} {
							set err "Unnamed favorite in forecast"
							error\
								$err\
								""\
								SELN_UNNAMED_FAV_IN_CAST
						}
					}

					if {$LEG($l,price_type) != "D"} {
						set err "price type $LEG($l,price_type) not valid "
						append err "for $LEG($l,leg_sort). must be dividends"
						error\
							$err\
							""\
							SELN_CAST_NOT_DIVIDEND
					}
					set LEG($l,lp_num) ""
					set LEG($l,lp_den) ""

					# already checked price
					set check_price 0
				}
				"SC" {
					set check_price 0
					# already checked that we have two legs
					set avail 0
					foreach {
						avail
						status
						num
						den
					} [_fscs_leg\
					       [lindex $selns 0]\
					       [lindex $selns 1]] {break}

					# check availability
					if {!$avail} {
						error\
							"SC not available"\
							""\
							"SELN_SC_NOT_AVAILABLE"
					}

					# check status
					if {$status != "A" && [_get_config seln_suspended_override] == "Y" &&
						[_get_config shop_bet_notification] == "N"} {
						_need_override LEG $l SUSP
					}

					# check scorecast price
					if {$LEG($l,lp_num) == "" || $LEG($l,lp_den) == ""} {
						set LEG($l,lp_num) $num
						set LEG($l,lp_den) $den
					} else {
						# we can allow price changes if the odds have lengthened
						if {[_get_config "ignore_price_change"] == "prc_better" &&
							(($LEG($l,lp_num) * $den) <
							 ($LEG($l,lp_den) * $num))} {
							# make sure we take the better price
							set LEG($l,lp_num) $num
							set LEG($l,lp_den) $den

						# If the user wants to be prompted always
						# Or if the odds have shortened and he wants
						# to be prompted when this is the case
						} elseif {
							($LEG($l,lp_num) != $num ||
							$LEG($l,lp_den) != $den) &&
							 [_get_config "ignore_price_change"] != "prc_all"
						} {

							set LEG($l,expected_lp_num) $num
							set LEG($l,expected_lp_den) $den

							if {[_get_config shop_bet_notification] == "N"} {
								_need_override LEG $l PRC_CHG
							}

						# If the user does not want to be prompted even if
						# the price is worse
						} elseif {
							($LEG($l,lp_num) != $num ||
							$LEG($l,lp_den) != $den) &&
							 [_get_config "ignore_price_change"] == "prc_all"
						} {

							set LEG($l,lp_num) $num
							set LEG($l,lp_den) $den
						}
					}

					set LEG($l,pot_lp_num) $LEG($l,lp_num)
					set LEG($l,pot_lp_den) $LEG($l,lp_den)

				}
				default {
					error\
						"cant have multiple parts -sort $LEG($l,leg_sort)"\
						""\
						"SELN_MULT_PART_NON_COMPLEX"
				}
			}

			# can't have ews on complex legs
			set LEG($l,ew_avail) "N"
			set LEG($l,pl_avail) "N"
		} else {
			set s [lindex $selns 0]

			if { [info exists LEG($l,leg_type)] && \
			     ( $LEG($l,leg_type) == "E" || $LEG($l,leg_type) == "P" ) && \
			     $LEG($l,ew_fac_num) != "" && \
			     $LEG($l,ew_fac_den) != "" && \
			     $LEG($l,ew_places)  != "" && \
			     ( $LEG($l,ew_fac_num) != $SELN($s,ew_fac_num) || \
			       $LEG($l,ew_fac_den) != $SELN($s,ew_fac_den) || \
			       $LEG($l,ew_places)  != $SELN($s,ew_places)   ) } {

				set LEG($l,expected_ew_fac_num) $SELN($s,ew_fac_num)
				set LEG($l,expected_ew_fac_den) $SELN($s,ew_fac_den)
				set LEG($l,expected_ew_places) $SELN($s,ew_places)

				set LEG($l,ew_avail)   $SELN($s,ew_avail)
				set LEG($l,pl_avail)   $SELN($s,pl_avail)
				set LEG($l,pot_lp_num) $SELN($s,lp_num)
				set LEG($l,pot_lp_den) $SELN($s,lp_den)

				_need_override LEG $l EW_CHG

			} else {

				set LEG($l,ew_avail)   $SELN($s,ew_avail)
				set LEG($l,pl_avail)   $SELN($s,pl_avail)
				set LEG($l,ew_fac_num) $SELN($s,ew_fac_num)
				set LEG($l,ew_fac_den) $SELN($s,ew_fac_den)
				set LEG($l,ew_places)  $SELN($s,ew_places)

				set LEG($l,pot_lp_num) $SELN($s,lp_num)
				set LEG($l,pot_lp_den) $SELN($s,lp_den)
			}

		}

		set seln [lindex $selns 0]

		# check price
		# we've already checked the price for multipart legs
		if {$check_price} {
			_log INFO "LEG $l - Checking price of selections"

			# supply default price type if it hasn't been defined
			# this should only be for non complex legs
			if {$LEG($l,price_type) == ""} {
				if {$SELN($seln,lp_avail) == "Y" &&
					$SELN($seln,lp_num) != "" &&
					$SELN($seln,lp_den) != ""} {
					set LEG($l,price_type) "L"
				} else {
					set LEG($l,price_type) "S"
				}
			}
			set price_type $LEG($l,price_type)

			switch -- $price_type {
				"G" -
				"L" {
					# Guarateed price and live price

					# Guaranteed price extra checks
					if {$price_type == "G"} {
						if {$SELN($seln,gp_avail) != "Y" ||
							$SELN($seln,sp_avail) != "Y"} {
							error\
							    "Starting price and guaranteed price not avail"\
							    ""\
							    "SELN_NO_GP"
						}
					}


					if {$SELN($seln,lp_avail) != "Y" ||
					    $SELN($seln,lp_num) == "" ||
					    $SELN($seln,lp_den) == ""} {
						_need_override LEG $l NO_LP
					}

					# if we haven't given a live price copy from DB
					if {$LEG($l,lp_num) == "" || $LEG($l,lp_den) == ""} {
						#need to check that there is a price in the db
						if {$SELN($seln,lp_num) == "" ||
						    $SELN($seln,lp_den) == ""} {
							error\
							    "Must specify LP as none in DB"\
							    ""\
							    "SELN_MUST_GIVE_LP"
						}
						set LEG($l,lp_num) $SELN($seln,lp_num)
						set LEG($l,lp_den) $SELN($seln,lp_den)

					} elseif {
					     $SELN($seln,lp_num) != "" &&
					     $SELN($seln,lp_den) != ""
					} {

						set allowed 0

						# we can allow price changes if the odds have lengthened
						if { [_get_config "ignore_price_change"] == "prc_better" &&
						     (($LEG($l,lp_num) * $SELN($seln,lp_den)) <
						      ($LEG($l,lp_den) * $SELN($seln,lp_num)))
						} {
							set allowed 1
							# make sure we take the better price
							_log WARNING "LEG $l - Ignoring price change"

							if {[_get_config "best_price_change"] == "Y"} {
								set LEG($l,expected_lp_num) $LEG($l,lp_num)
								set LEG($l,expected_lp_den) $LEG($l,lp_den)
								set LEG($l,lp_num) $SELN($seln,lp_num)
								set LEG($l,lp_den) $SELN($seln,lp_den)
								set LEG($l,best_price_change) 1
							}
						}

						# dont throw PRC_CHG when betting
						# on two different hcap variants from the same selection
						if {[info exists LEG($l,ocv_id)] &&
							[info exists SELN($seln,oc_var_id)] &&
							$LEG($l,ocv_id) != $SELN($seln,oc_var_id)} {
							set allowed 1
						}

						if {
							!$allowed &&
							($SELN($seln,lp_num) != "" && $SELN($seln,lp_den) != "") &&
							(($LEG($l,lp_num) != $SELN($seln,lp_num)) ||
							 ($LEG($l,lp_den) != $SELN($seln,lp_den)))
						} {
							set LEG($l,expected_lp_num) $SELN($seln,lp_num)
							set LEG($l,expected_lp_den) $SELN($seln,lp_den)

							if {[_get_config shop_bet_notification] == "N"} {
								_need_override LEG $l PRC_CHG
							}

						# If the user does not want to be prompted even if
						# the price is worse
						} elseif { ($LEG($l,lp_num) != $SELN($seln,lp_num) ||
							   $LEG($l,lp_den) != $SELN($seln,lp_den)) &&
							   [_get_config "ignore_price_change"] == "prc_all"
						} {
							set LEG($l,lp_num) $SELN($seln,lp_num)
							set LEG($l,lp_den) $SELN($seln,lp_den)
						}
					}

					# The pot_lp_num and pot_lp_den are used to calculate the potential winnings and
					# if using lp_num and lp_den instead of expected_lp_num and expected_lp_den then
					# negative price changes are ignored for the potential winnings.  if the betslip
					# is updated to show the new price, the potential winnings doesn't looking wrong

					if {[info exists LEG($l,expected_lp_num)] && [info exists LEG($l,expected_lp_den)]} {
						set LEG($l,pot_lp_num) $LEG($l,expected_lp_num)
						set LEG($l,pot_lp_den) $LEG($l,expected_lp_den)
					} else {
                        set LEG($l,pot_lp_num) $LEG($l,lp_num)
                        set LEG($l,pot_lp_den) $LEG($l,lp_den)
					}
				}
				"S" {
					# Starting Price

					set LEG($l,lp_num) ""
					set LEG($l,lp_den) ""

					if {$SELN($seln,sp_avail) != "Y"} {
						_need_override LEG $l NO_SP
					}
				}
				"D" {
					# TODO - Check whether should have dividends bets on
					# non *cast
					error\
						"$l: dividends but not a *cast leg"\
						""\
						"SELN_DIVIDEND_NON_CAST"
				}
				"B" -
				"1" -
				"2" -
				"N" {
					# Best, First Show, Second Show or Next price
					if {[catch {_get_config exotic_prices,$price_type}]} {
						error\
							"$l: Price type $price_type is invalid"\
							""\
							"SELN_EXOTIC_INVALID"
					}

					set class_sort $SELN($seln,class_sort)

					if {[lsearch [get_config exotic_prices,$price_type] $class_sort]
						== -1} {
						error\
							"$l: Invalid price type $price_type/$class_sort"\
							""\
							"SELN_EXOTIC_INVALID_CLASS_SORT"
					}
					set LEG($l,lp_num) ""
					set LEG($l,lp_den) ""
				}
			}
		}

		# check bir index
		_log INFO "LEG $l - Checking bir index"
		if {$LEG($l,bir_index) == ""} {
			# safe as no bir index on scorecasts
			set LEG($l,bir_index) $SELN($seln,bir_index)
		} else {
			if {$LEG($l,bir_index) != $SELN($seln,bir_index)} {
				set LEG($l,expected_bir_index) $SELN($seln,bir_index)
				if {[_get_config shop_bet_notification] == "N"} {
					_need_override LEG $l BIR_CHG
				}
			}
		}

		# check handicap
		::ob_bet::_log INFO "LEG $l - Checking handicap"
		if {$LEG($l,hcap_value) == ""} {
			# safe as no hcap value on scorecasts
			set LEG($l,hcap_value) $SELN($seln,hcap_value)
		} else {
			# special case - dont throw HCAP_CHG when betting
			# on two different hcap variants from the same selection
			if {!([info exists LEG($l,ocv_id)] &&
				[info exists SELN($seln,oc_var_id)] &&
				$LEG($l,ocv_id) != $SELN($seln,oc_var_id) )} {

				# We will use index delta tolerance if it is activated and is not null
				if { [_get_config "use_tolerance"] && $SELN($seln,tolerance) != "" } {
					set tolerance $SELN($seln,tolerance)

					if { [expr $LEG($l,hcap_value) - $tolerance] > $SELN($seln,hcap_value) ||
					     [expr $LEG($l,hcap_value) + $tolerance] < $SELN($seln,hcap_value) } {

						if {[_get_config "ignore_hcap_change"] == "Y"} {
							set LEG($l,hcap_value) $SELN($seln,hcap_value)
						} else {
							set LEG($l,expected_hcap_value) $SELN($seln,hcap_value)
							if {[_get_config shop_bet_notification] == "N"} {
								_need_override LEG $l HCAP_CHG
							}
						}
					} else {
						set SELN($seln,hcap_value) $LEG($l,hcap_value)
					}

				} elseif {$LEG($l,hcap_value) != $SELN($seln,hcap_value)} {
					if {[_get_config "ignore_hcap_change"] == "Y"} {
						set LEG($l,hcap_value) $SELN($seln,hcap_value)
					} else {
						set LEG($l,expected_hcap_value) $SELN($seln,hcap_value)
						if {[_get_config shop_bet_notification] == "N"} {
							_need_override LEG $l HCAP_CHG
						}
					}
				}
			}
		}

		# for AH with a split line we need to adjust the stake
		# per line to consider this a two line bet
		if {$leg_sort == "AH" && round($LEG($l,hcap_value)) % 2 != 0} {
			set LEG($l,ah_split_line) "Y"
		}

		# get min and max combi
		::ob_bet::_log INFO "LEG $l - Checking min/max combi, if started & bir_delay"
		foreach s $selns {
			if {$SELN($s,acc_min) != ""} {
				set LEG($l,min_combi)\
					[expr {$SELN($s,acc_min) > $LEG($l,min_combi)
				           ? $SELN($s,acc_min)
				           : $LEG($l,min_combi)}]
			}
			if {$SELN($s,acc_max) != ""} {
				set LEG($l,max_combi)\
					[expr {$SELN($s,acc_max) < $LEG($l,max_combi)
				           ? $SELN($s,acc_max)
				           : $LEG($l,max_combi)}]
			}

			# suspended
			# check status
			if {$SELN($s,status) != "A" && [_get_config seln_suspended_override] == "Y" &&\
				[_get_config shop_bet_notification] == "N"} {
				_need_override LEG $l SUSP
			}

			# make sure for SC we take the bir falg from the SC mkt TODO
			if {$SELN($s,ev_suspended)== "Y"} {
				set off 1
			} elseif {$SELN($s,in_running) == "Y" ||
					  $SELN($s,is_off) == "N"} {
				set off 0
			} elseif {$SELN($s,is_off) == "Y" ||
					  $SELN($s,ev_started) == "Y"} {
				set off 1
			} else {
				set off 0
			}
			if {$off && [_get_config ev_started_override] == "Y" && [_get_config shop_bet_notification] == "N"} {
				_need_override LEG $l START
			}

			# add any started BIR selection to the bet_delay queue
			if {
				[_get_config server_bet_delay] == "Y" &&
				$SELN($s,in_running) == "Y" &&
				($SELN($s,ev_started) == "Y" || $SELN($s,is_off) == "Y") &&
				($SELN($s,bir_delay) > 0 || [_get_config server_bet_def_delay] > 0)
			} {
				_bir_set_leg_delay $l $SELN($s,bir_delay)
			}

			set start_time_secs [clock scan $SELN($s,start_time)]

			# indicate if any selection is in-running
			if {$SELN($s,in_running) == "Y" &&  \
				($SELN($s,is_off) == "Y" || \
				($SELN($s,is_off) == "-" && $start_time_secs < [clock seconds]))} {
				set LEG($l,has_bir_seln) "Y"
			} else {
				set LEG($l,has_bir_seln) "N"
			}
		}

		if {$LEG($l,max_combi) < $LEG($l,min_combi)} {
			# shouldn't occur due to check constraint
			set err "leg $l: max_combi = $LEG($l,max_combi)"
			append err " min_combi = $LEG($l,min_combi)"
			error\
				$err\
				""\
				"SELN_MAXCOMBI_LT_MINCOMBI"
		}
		if {$LEG($l,max_combi) == 1} {
			set LEG($l,can_combi) "N"
		}
	}

	# see what legs each one cannot be combined with
	for {set l 0} {$l < $LEG(num)} {incr l} {

		lappend COMBI($l,no_combi_legs) $l
		for {set l2 [expr {$l + 1}]} {$l2 < $LEG(num)} {incr l2} {
			if {![_can_combine_leg $l $l2]} {
				lappend COMBI($l,no_combi_legs)  $l2
				lappend COMBI($l2,no_combi_legs) $l
			}
		}
	}

	_log INFO "Selections verifyed"
}



# Get selections from the DB
#
proc ob_bet::_get_selns {} {

	variable SELN
	variable LEG
	variable MAX_SELN_PLACEHOLDERS

	if {![_smart_reset SELN]} {
		# already retrieved the selection information
		return
	}

	if {[_smart_reset LEG] || $LEG(num) == 0} {
		error\
			"No selections have been added"\
			""\
			"SELN_NO_SELNS"
	}

	_log INFO "Retrieving selections from db ..."

	_verify_variants

	set mkts  [list]
	set evs   [list]
	set types [list]
	set SELN(repeated_mkts) [list]
	set SELN(repeated_types) [list]
	set SELN(repeated_evs) [list]

	set selns $LEG(selns)
	set ocv_ids $LEG(ocv_ids)

	# can only get up to MAX_SELN_PLACEHOLDERS selections at a time
	# So may need to call this query a number of times
	set num_selns [llength $selns]
	set num_ocvs  [llength $ocv_ids]
	set num_places  $MAX_SELN_PLACEHOLDERS
	set num_fillers [expr {$num_places - ($num_selns % $num_places)}]
	set num_ocv_fillers [expr {$num_places - ($num_ocvs % $num_places)}]

	# Pad out selns and ocv_ids so that it has enough to fill up
	# the placeholders in the query
	set padded_selns   $selns
	set padded_ocv_ids $ocv_ids
	for {set i 0} {$i < $num_fillers} {incr i} {
		lappend padded_selns -1
	}
	for {set k 0} {$k < $num_ocv_fillers} {incr k} {
		lappend padded_ocv_ids -1
	}

	for {set l 0} {$l < $num_selns} {incr l $num_places} {

		# build up the query string
		set seln_subset [lrange $padded_selns $l   [expr {$l + $num_places - 1}]]
		set ocv_subset  [lrange $padded_ocv_ids $l [expr {$l + $num_places - 1}]]
		set qry "ob_db::exec_qry ob_bet::get_selns $seln_subset $ocv_subset"

		# execute the selns query and retrieve the results
		if {[catch {set rs [eval $qry]} msg]} {
			error\
				"Unable to retrieve selections from db: $msg"\
				""\
				"SELN_DB_ERROR"
		}
		set n_rows [db_get_nrows $rs]

		set SELN(COLS) [db_get_colnames $rs]

		for {set r 0} {$r < $n_rows} {incr r} {
			set oc    [db_get_col $rs $r ev_oc_id]
			set mkt   [db_get_col $rs $r ev_mkt_id]
			set ev    [db_get_col $rs $r ev_id]
			set type  [db_get_col $rs $r ev_type_id]

			lappend SELN(mkt,$mkt,selns)   $oc
			lappend SELN(ev,$ev,selns)     $oc
			lappend SELN(type,$type,selns) $oc

			#index the repeated ocs,evs and types
			if {[lsearch $mkts $mkt] != -1} {
				if {[lsearch $SELN(repeated_mkts) $mkt] == -1} {
					lappend SELN(repeated_mkts) $mkt
				}
			} elseif {[lsearch $evs $ev] != -1} {
				if {[lsearch $SELN(repeated_evs) $ev] == -1} {
					lappend SELN(repeated_evs) $ev
				}
			} elseif {[lsearch $types $type] != -1} {
				if {[lsearch $SELN(repeated_types) $type] == -1} {
					lappend SELN(repeated_types) $type
				}
			}

			if {[lsearch $mkts $mkt] == -1} {
				lappend mkts $mkt
			}
			if {[lsearch $evs $ev] == -1} {
				lappend evs $ev
			}
			if {[lsearch $types $type] == -1} {
				lappend types $type
			}

			# add the selection details
			lappend SELN(selns) $oc
			foreach f [db_get_colnames $rs] {
				set SELN($oc,$f) [db_get_col $rs $r $f]
			}

			# If we're not allowing eachway on unnamed favourites then
			# deal with this here.
			if {[_get_config allow_ew_on_favourite] == "N"} {
				if {$SELN($oc,fb_result) != "-"} {
					set SELN($oc,ew_avail) "N"
					set SELN($oc,pl_avail) "N"
				}
			}

			# Default all the selections to have a stake factor of 1, then
			# update where appropriate
			set SELN($oc,sf) 1.00

			incr SELN(num)
		}
		ob_db::rs_close $rs

		# Are we applying dynamic stake factors to bets?
		if {[_get_config allow_stk_fac_profiles] == "Y"} {
			set qry "ob_db::exec_qry ob_bet::get_dynamic_stake_factors\
						$seln_subset $seln_subset $seln_subset $seln_subset"
			if {[catch {set rs [eval $qry]} msg]} {
				error\
					"Unable to retrieve selection stake factors from db: $msg"\
					""\
					"SELN_DB_ERROR"
			}
			set nrows [db_get_nrows $rs]
			set current [clock seconds]

			for {set i 0} {$i < $nrows} {incr i} {
				set level      [db_get_col $rs $i level]
				set oc         [db_get_col $rs $i ev_oc_id]
				set start_time [db_get_col $rs $i start_time]
				set from       [db_get_col $rs $i mins_before_from]
				set to         [db_get_col $rs $i mins_before_to]
				set sf         [db_get_col $rs $i stake_factor]

				set mins_before [expr ([clock scan $start_time] - $current)/60]

				# Only update if for current time t, $from >= t > $to
				# Note, $from can be null but $to can't, and no two rows
				# should overlap for the same level and ev_oc_id
				if {($from == "" && $mins_before > $to) ||
						($from >= $mins_before && $mins_before > $to)} {
					if {![info exists SELN($oc,sf_level)]} {
						# Nothing's added for this selection yet so just update
						set SELN($oc,sf_level) $level
						set SELN($oc,sf)       $sf
					} elseif {$SELN($oc,sf_level) == $level ||
								($SELN($oc,sf_level) == "CATEGORY" &&
									($level == "CLASS" || $level == "TYPE" ||
									$level == "EVENT")) ||
								($SELN($oc,sf_level) == "CLASS" &&
									($level == "TYPE" || $level == "EVENT")) ||
								($SELN($oc,sf_level) == "TYPE" &&
									$level == "EVENT")} {
						# The lowest level in the hierarchy takes priority, so only
						# update if the new level is the same or lower than the old
						set SELN($oc,sf_level) $level
						set SELN($oc,sf)       $sf
					}
				}
			}

			ob_db::rs_close $rs
		}
	}
	# end of max selns loop
}

::ob_bet::_log INFO "sourced selection.tcl"
