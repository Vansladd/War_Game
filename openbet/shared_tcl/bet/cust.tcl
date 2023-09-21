################################################################################
# $Id: cust.tcl,v 1.1 2011/10/04 12:26:11 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Handle customer specifics of bet placement
#
# Configuration:
#    Does not read config file use ob_bet::init -[various options] to
#    customise
#
# Synopsis:
#    package require bet_bet ?4.5?
#
# Procedures:
#    ob_bet::set_cust        Set up customer details
#    ob_bet::set_cash_cust   Set up anonymous betting terminal
#
################################################################################
namespace eval ob_bet {
	namespace export set_cust
	namespace export set_cash_cust
	namespace export cust_status_can_bet

	variable CUST
}



#API:set_cust Set the customer placing the bet
#
#Usage
#  ob_bet::set_cust cust_id acct_id check
#
#  Set the customer placing the bet.
#
# Parameters:
# cust_id   FORMAT: INT  DESC: tCustomer.cust_id
# acct_id   FORMAT: INT  DESC: tAcct.acct_id
# check     FORMAT: 1|0
#           DESC:   Whether the account should be checked for available funds
#                   Active/Suspended etc...
#
proc ::ob_bet::set_cust {cust_id acct_id {check 1}} {

	_log INFO "API(set_cust): $cust_id,$acct_id,$check"

	if {[catch {
		set ret [eval _set_cust {$cust_id} {$acct_id} {$check}]
	} msg]} {
		_err $msg
	}
	return $ret
}



#API:set_cash_cust Set the account for anon cash betting
#
#Usage
#  ob_bet::set_cash_cust cust_id ccy_code
#
# Parameters:
# term_code FORMAT: VARCHAR  DESC: tAdminTerm.term_code
# ccy_code  FORMAT: CHAR(3)  DESC: tAcct.ccy_code
#
proc ::ob_bet::set_cash_cust {term_code ccy_code} {

	_log INFO "API(set_cash_cust): $term_code,$ccy_code"

	if {[catch {
		set ret [eval _set_cash_cust {$term_code} {$ccy_code}]
	} msg]} {
		_err $msg
	}
	return $ret
}

#API:get the max_stake_scale for this customer
#
#Usage
#  ob_bet::get_cust_ev_lvl_limits bet_no
#
# Parameters:
# bet_no FORMAT: INT  DESC: bet package bet_no
#
proc ::ob_bet::get_cust_ev_lvl_limits {bet_no} {

	variable BET

	set group_id $BET($bet_no,group_id)
	return [_get_cust_ev_lvl_limits $group_id]

}

# MARTA TODO: Copied from PP, not sure if needed.
proc ::ob_bet::cust_status_can_bet {status} {
	switch -- $status {
		A  -
		D  -
		T  { return 1 }
	}
	# no betting allowed
	return 0
}

#END OF API..... private procedures



#prepare customer queries
proc ob_bet::_prepare_cust_qrys {} {

	variable CONFIG

	ob_db::store_qry ob_bet::cum_stake {
		select {+INDEX (b ibet_x2)}
		  s.ev_oc_id,
		  DECODE (s.price_type, 'S', 'S', 'L') price_type,
		  b.leg_type,
		  b.bet_type,
		  s.leg_sort,
		  NVL(ocv.oc_var_id,-1) as oc_var_id,
		  SUM(b.stake_per_line * s.bets_per_seln) cum_stake,
		  NVL(SUM(case
			when b.num_legs == 1 then 0
			else b.stake_per_line * s.bets_per_seln
			end),0)
		  as cum_mult_stakes,
		  NVL(SUM(case
			when NVL(o.price_changed_at, b.cr_date) > b.cr_date then 0
			else b.stake_per_line * s.bets_per_seln
			end),0) as cum_stake_lastprice,
		  NVL(SUM(case
			when b.num_legs <> 1 and NVL(o.price_changed_at, b.cr_date) <= b.cr_date then
				b.stake_per_line * s.bets_per_seln
			else 0
			end),0) as cum_mult_stakes_lastprice,
		  NVL(SUM(case
			when NVL(ocv.price_changed_at, b.cr_date) > b.cr_date then 0
			else b.stake_per_line * s.bets_per_seln
		    end),0) as cum_stake_lastprice_variant,
		  NVL(SUM(case
			when b.num_legs <> 1 and NVL(ocv.price_changed_at, b.cr_date) <= b.cr_date then
				b.stake_per_line * s.bets_per_seln
			else 0
		    end),0) as cum_mult_stakes_lastprice_variant
		from
			tBet   b,
			tOBet  s,
			tEvOc  o,
			tEvMkt m,
			outer tEvOcVariant ocv
		where
			b.acct_id = ? and
			b.cr_date > CURRENT- ? units second and
			b.bet_id = s.bet_id and
			b.status <> 'X' and
			s.ev_oc_id = o.ev_oc_id and
			o.ev_mkt_id = m.ev_mkt_id and
			NVL(s.bir_index,-1) = NVL(m.bir_index,-1) and
			s.ev_oc_id  in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) and
			s.ev_oc_id = ocv.ev_oc_id and
			m.ev_mkt_id = ocv.ev_mkt_id and
			(
				(ocv.type = 'HC' and s.hcap_value = ocv.value) or
				(ocv.type = '--' and s.hcap_value is null)
			)

		group by 1,2,3,4,5,6;
	}

	ob_db::store_qry ob_bet::cust_ev_lvl_limits {
		select
			c.level,
			c.id,
			c.max_stake_scale,
			c.liab_group_id,
			l.intercept_value,
			l.liab_desc
		from
			tCustLimit c,
			outer tLiabGroup l
		where
			cust_id = ? and
			c.liab_group_id = l.liab_group_id
	}

	ob_db::store_qry ob_bet::cust_details {
		select
			c.cust_id,
			c.status,
			c.max_stake_scale,
			c.bet_count,
			a.balance,
			a.credit_limit,
			a.acct_type,
			a.owner_type,
			a.owner as acct_owner,
			y.exch_rate,
			l.intercept_value,
			l.liab_desc,
			r.code as cust_code
		from
			tcustomer c,
			tacct a,
			tccy  y,
			outer tliabgroup l,
			outer tCustomerReg r
		where
			c.cust_id = a.cust_id
		and
			a.ccy_code = y.ccy_code
		and
			l.liab_group_id = c.liab_group
		and
			c.cust_id = r.cust_id
		and
			a.acct_id = ?
	}

	ob_db::store_qry ob_bet::lock_acct {
		update tcustomer
		set
		  bet_count = bet_count
		where
		  cust_id = ?
	}

	ob_db::store_qry ob_bet::lock_term_acct {
		update tadminterm
		set
		  bet_count = bet_count
		where
		  term_code = ?
	}

	if {$CONFIG(allow_cash_customer) == "Y"} {
		ob_db::store_qry ob_bet::get_CB_details {
			select
				a.acct_id,
				a.acct_type,
				a.cust_id
			from
				tTermAcct ta,
				tAcct a
			where
				ta.term_code = ?
			and
				a.ccy_code = ?
			and
				a.acct_type = 'PUB'
			and
				ta.acct_id = a.acct_id
		} 600
	}
}



#set the customer placing the bet
proc ::ob_bet::_set_cust {cust_id acct_id {check 1}} {

	variable CUST

	if {![_smart_reset CUST] || $CUST(num) != 0} {
		error\
			"Details have already been added.  Call ::ob_bet::clear first"\
			""\
			CUST_ALREADY_SET
	}

	set CUST(anon)    0
	set CUST(cust_id) $cust_id
	set CUST(acct_id) $acct_id
	set CUST(num)     1
	set CUST(check)   $check

}



#declares that this customer is betting anonymously
proc ::ob_bet::_set_cash_cust {term_code ccy_code} {

	variable CUST

	if {![_smart_reset CUST] || $CUST(num) != 0} {
		error\
			"Details have already been added.  Call ::ob_bet::clear first"\
			""\
			CUST_ALREADY_SET
	}

	set CUST(anon)  1
	set CUST(check) 1
	set CUST(term_code) $term_code
	set CUST(ccy_code) $ccy_code
	set CUST(num)   1


	#Get the customer and account IDs
	_get_cash_cust_details
}



# returns the type of calculation for cumulative stakes, to identify the
# applicable row in the result set from the cum_stakes query
proc ::ob_bet::_get_cum_stakes_calculation {prev_stk_bir prev_stk_nobir is_bir} {

	if { $prev_stk_bir == "Y" && $is_bir == "Y" } {
		return "PriceChanged"
	} elseif { $prev_stk_nobir == "Y" && $is_bir == "N" } {
		return "PriceChanged"
	} else {
		return "Default"
	}

}



#gets customer details: should only be called after all the legs have
#been added as will look at cumulative stakes.
proc ::ob_bet::_get_cust_details {} {

	variable CUST
	variable CUST_DETAILS
	variable LEG
	variable SELN
	variable MAX_SELN_PLACEHOLDERS

	#check we already have customer and leg details
	if {[_smart_reset CUST] || $CUST(num) == 0} {
		error\
			"No customer has been added call ::ob_bet::set_cust"\
			""\
			CUST_DETAILS_NO_CUST
	}

	_smart_reset LEG
	_smart_reset XSTK
	_smart_reset BET_TYPE_LIMITS

	if {![_smart_reset CUST_DETAILS]} {
		#already received from the DB
		return
	}


	# make sure we have all the necessary selection information
	#_verify_selns

	::ob_bet::_log INFO "::ob_bet::_get_cust_details - Getting cust details ..."

	set acct_id $CUST(acct_id)

	set rs [ob_db::exec_qry ob_bet::cust_details $acct_id]
	if {[db_get_nrows $rs] == 0} {
		ob_db::rs_close $rs
		error\
			"Cannot find customer"\
			""\
			CUST_DETAILS_NO_CUST
	} elseif {[db_get_nrows $rs] != 1} {
		ob_db::rs_close $rs
		error\
			"Expected 1 row from query got [db_get_nrows $rs]"\
			""\
			CUST_DETAILS_MULT_ROWS
	}

	#check the cust_id and the acct_id supplied match
	#don't check for anonymous as we are checking the
	#balance of the CSH account and not the bet account.
	set c [db_get_col $rs 0 cust_id]
	if {$c != $CUST(cust_id)} {
		error\
			"Invalid customer id expected $c got $CUST(cust_id)"\
			""\
			CUST_DETAILS_INVALID_CUST
	}

	set CUST_DETAILS(status)          [db_get_col $rs 0 status]
	set CUST_DETAILS(max_stake_scale) [db_get_col $rs 0 max_stake_scale]
	set CUST_DETAILS(balance)         [db_get_col $rs 0 balance]
	set CUST_DETAILS(bet_count)       [db_get_col $rs 0 bet_count]
	set CUST_DETAILS(credit_limit)    [db_get_col $rs 0 credit_limit]
	set CUST_DETAILS(exch_rate)       [db_get_col $rs 0 exch_rate]
	set CUST_DETAILS(acct_type)       [db_get_col $rs 0 acct_type]
	set CUST_DETAILS(owner_type)      [db_get_col $rs 0 owner_type]
	set CUST_DETAILS(acct_owner)      [db_get_col $rs 0 acct_owner]
	set CUST_DETAILS(cust_code)       [db_get_col $rs 0 cust_code]

	if {[_get_config async_enable_intercept] == "Y"} {
		set CUST_DETAILS(intercept_value) [db_get_col $rs 0 intercept_value]
	} else {
		set CUST_DETAILS(intercept_value) ""
	}
	set CUST_DETAILS(liab_desc)       [db_get_col $rs 0 liab_desc]

	ob_db::rs_close $rs

	#check the status
	if {$CUST_DETAILS(status) != "A"} {
		_need_override CUST $CUST(cust_id) NO_BETTING
	}

	ob_log::write INFO {BET - Getting class scale factors...}
	set rs [ob_db::exec_qry ob_bet::cust_ev_lvl_limits $CUST(cust_id)]
	for {set r 0} {$r < [db_get_nrows $rs]} {incr r} {
		set level            [db_get_col $rs $r level]
		set id               [db_get_col $rs $r id]
		set max_stake_scale  [db_get_col $rs $r max_stake_scale]
		set liab_group_id    [db_get_col $rs $r liab_group_id]
		set liab_desc        [db_get_col $rs $r liab_desc]
		if {[_get_config async_enable_intercept] == "Y"} {
			set intercept_value  [db_get_col $rs $r intercept_value]
		} else {
			set intercept_value ""
		}
		if {$max_stake_scale != ""} {
			set CUST_DETAILS(stake_scale,$level,$id) $max_stake_scale
		}

		if {$liab_group_id != ""} {
			set CUST_DETAILS(liab_group,$level,$id)       $liab_group_id
			set CUST_DETAILS(liab_desc,$level,$id)        $liab_desc
			if {[_get_config async_enable_intercept] == "Y"} {
				set CUST_DETAILS(intercept_value,$level,$id)  $intercept_value
			} else {
				set CUST_DETAILS(intercept_value,$level,$id)  ""
			}
		} else {
			set CUST_DETAILS(liab_group,$level,$id)       ""
			set CUST_DETAILS(liab_desc,$level,$id)        ""
			set CUST_DETAILS(intercept_value,$level,$id)  ""
		}
	}

	ob_db::rs_close $rs

	# set the acct_id for the customer
	set acct_id $CUST(acct_id)

	# get cumulative stakes delay value for customer accounts
	set cum_stakes_delay [ob_control::get cum_stakes_delay]

	# Get previous stakes only at price change overrides set up
	set prev_stk_bir      [ob_control::get prev_stk_bir]
	set prev_stk_nobir    [ob_control::get prev_stk_nobir]

	::ob_bet::_log DEBUG " Cumulative Stakes delay      : $cum_stakes_delay"
	::ob_bet::_log DEBUG " BIR Ignore previous stk?     : $prev_stk_bir"
	::ob_bet::_log DEBUG " NON BIR ignore previous stk? : $prev_stk_nobir"

	# if using anonymous betting get the private acct_id.
	# note: acct_id is set above to CUST(acct_id)
	if {$CUST(anon)} {
		# get the anonymous cumulative stakes delay
		set cum_stakes_delay [_get_config anon_cum_stakes_delay]
		# if it is set to the default then get it from
		# the database
		if {$cum_stakes_delay == ""} {
			set cum_stakes_delay [ob_control::get anon_cum_stk_delay]
		}
		::ob_bet::_log DEBUG \
			" Overriding Cum Stakes delay with \
			anonymous bet value of $cum_stakes_delay"
	}

	if {$cum_stakes_delay != "" &&
	    $cum_stakes_delay != 0} {
		::ob_bet::_log INFO " Calculating cumulative stakes ..."

		set CUST_DETAILS(found_cum_stakes) 1

		if {$LEG(num)} {
			set selns $LEG(selns)
		} else {
			set selns [list]
		}

		set num_selns [llength $selns]

		if {$CUST(anon)} {
			set acct_id $CUST(bet_acct_id)
			::ob_bet::_log DEBUG { Using anonymous acct_id : $acct_id}
		} else {
			set acct_id $CUST(acct_id)
		}

		#can only get up to MAX_SELN_PLACEHOLDERS selections at a time
		#So may need to call this query a number of times
		for {set l 0} {$l * $MAX_SELN_PLACEHOLDERS < $num_selns} {incr l} {

			# build up the query string
			set qry [list "ob_db::exec_qry ob_bet::cum_stake $acct_id $cum_stakes_delay"]

			set start_idx [expr {$l * $MAX_SELN_PLACEHOLDERS}]
			set end_idx [expr {$start_idx + $MAX_SELN_PLACEHOLDERS}]
			for {set r $start_idx} {$r < $end_idx} {incr r} {
				if {$r < $num_selns} {
					set seln [lindex $selns $r]
					lappend qry $seln

					set CUST_DETAILS(cum_stake,$seln,L,W)   0.0
					set CUST_DETAILS(cum_stake,$seln,S,W)   0.0
					set CUST_DETAILS(cum_stake,$seln,L,P)   0.0
					set CUST_DETAILS(cum_stake,$seln,S,P)   0.0
					set CUST_DETAILS(cum_stake,$seln,F)     0.0
					set CUST_DETAILS(cum_stake,$seln,T)     0.0
					set CUST_DETAILS(cum_stake,$seln,SGL)   0.0
					set CUST_DETAILS(cum_mult_stakes,$seln) 0.0
				} else {
					#going to pad out the placeholders as there is a problem
					#with informix 9 if placeholders are not given a value
					lappend qry "-1"
				}
			}


			#get the cum stakes from the DB
			if {[catch {set rs [eval [join $qry " "]]} msg]} {
				error\
					"Unable to retrieve cum stake from db: $msg"\
					""\
					CUST_DETAILS_CUM_STAKE
			}
			set n_rows [db_get_nrows $rs]

			for {set r 0} {$r < $n_rows} {incr r} {

				set ev_oc_id   [db_get_col $rs $r ev_oc_id]
				set price_type [db_get_col $rs $r price_type]
				set leg_type   [db_get_col $rs $r leg_type]
				set leg_sort   [db_get_col $rs $r leg_sort]
				set bet_type   [db_get_col $rs $r bet_type]

				# Work out what calculation to use
				set calculation [::ob_bet::_get_cum_stakes_calculation \
				                    $prev_stk_bir \
				                    $prev_stk_nobir \
				                    $SELN($ev_oc_id,in_running) ]

				::ob_bet::_log DEV "-------------- Row $r ---------------------"
				::ob_bet::_log DEV "  >> Selection: $ev_oc_id "
				::ob_bet::_log DEV "  >> Is BIR ? $SELN($ev_oc_id,in_running) "
				::ob_bet::_log DEV "  >> Leg is '$leg_type'"

				if {$calculation == "Default"} {
					::ob_bet::_log DEBUG "  >> USING Default for $ev_oc_id"
					set cum_stake        [db_get_col $rs $r cum_stake]
					set cum_mult_stakes  [db_get_col $rs $r cum_mult_stakes]
				} else {
					::ob_bet::_log DEBUG "  >> USING PriceChanged for  $ev_oc_id"
					if {[db_get_col $rs $r oc_var_id] == -1} {
						set cum_stake        [db_get_col $rs $r cum_stake_lastprice]
						set cum_mult_stakes  [db_get_col $rs $r cum_mult_stakes_lastprice]
					} else {
						set cum_stake        [db_get_col $rs $r cum_stake_lastprice_variant]
						set cum_mult_stakes  [db_get_col $rs $r cum_mult_stakes_lastprice_variant]
					}
				}

				if {[_get_config ew_mixed_multiple] == "Y" && $leg_type != "W"} {
					# try to work out if the selection was not involved in a
					# place line, in which case treat the stake as if it was
					# a win stake.
					# (this is a slightly dodgy test because it doesn't look at
					# how the bet was actually placed, but it's probably good enough)
					if {$SELN($ev_oc_id,ew_avail) == "N" && $SELN($ev_oc_id,pl_avail) == "N"} {
						set leg_type "W"
					}
				}

				if {$bet_type == "SGL" && $num_selns == 1} {
					set cum_stake_SGL $cum_stake
				} else {
					set cum_stake_SGL 0.0
				}

				switch -- $leg_type {
					"P" {
						set cum_stake_P $cum_stake
						set cum_stake_W 0.0
						set cum_stake_F 0.0
						set cum_stake_T 0.0
						if {$leg_sort == "SF"} {
							set cum_stake_F $cum_stake
						}
						if {$leg_sort == "TC"} {
							set cum_stake_T $cum_stake
						}
					}
					"Q" -
					"E" {
						set cum_stake_P [set cum_stake_W [expr {$cum_stake/ 2}]]
						set cum_stake_F 0.0
						set cum_stake_T 0.0
					}
					"W" -
					default {
						set cum_stake_W $cum_stake
						set cum_stake_P 0.0
						set cum_stake_F 0.0
						set cum_stake_T 0.0
						if {$leg_sort == "SF"} {
							set cum_stake_F $cum_stake
						}
						if {$leg_sort == "TC"} {
							set cum_stake_T $cum_stake
						}
					}
				}

				set CUST_DETAILS(cum_stake,$ev_oc_id,$price_type,W)\
					[expr {$CUST_DETAILS(cum_stake,$ev_oc_id,$price_type,W) + $cum_stake_W}]

				set CUST_DETAILS(cum_stake,$ev_oc_id,$price_type,P)\
					[expr {$CUST_DETAILS(cum_stake,$ev_oc_id,$price_type,P) + $cum_stake_P}]

				set CUST_DETAILS(cum_stake,$ev_oc_id,F)\
					[expr {$CUST_DETAILS(cum_stake,$ev_oc_id,F) + $cum_stake_F}]

				set CUST_DETAILS(cum_stake,$ev_oc_id,T)\
					[expr {$CUST_DETAILS(cum_stake,$ev_oc_id,T) + $cum_stake_T}]

				set CUST_DETAILS(cum_stake,$ev_oc_id,SGL)\
					[expr {$CUST_DETAILS(cum_stake,$ev_oc_id,SGL) + $cum_stake_SGL}]

				set CUST_DETAILS(cum_mult_stakes,$ev_oc_id)\
					[expr {$CUST_DETAILS(cum_mult_stakes,$ev_oc_id) + $cum_mult_stakes}]

			}
			ob_db::rs_close $rs
		}
		#end of maximum selections loop
	} else {
		set CUST_DETAILS(found_cum_stakes) 0
	}

	::ob_bet::_log INFO " Cust details have been retrieved ..."
	set CUST_DETAILS(num) 1
}



# Go through all of the outcomes involved in this bet to see if the customer
# has any rows in tCustLimit at the Class, Type or EvOcGrp level that match.
# For each outcome the most specific match will be used, i.e. the priority
# is EvOcGrp, Type, Class and then a default of tCustomer level settings. This
# function checks for max_stake_scale and intercept_value limits.
# Both limits are then set of the min of each outcomes most specific value
# for example:
# tCustomer.max_stake_scale = 2
# And for this customer
# Football max_stake_scale = 3
# Football->Premiership->WDW max_stake_scale = 4
# Racing  cust_max_stk_scale = 10
# Single on Cricket cust_max_stk_scale = 2
# Single on Racing cust_max_stk_scale = 10
# Single on Football->Premiership->WDW = 4
# Single on Football->Premiership->Correct Score = 3
# Double on Basketball and Football cust_max_stk_scale = 2
# Double on Racing and Football cust_max_stk_scale = 3
# Double on Racing and Football->Premiership->WDW cust_max_stk_scale = 4
#
proc ::ob_bet::_get_cust_ev_lvl_limits {group_id} {
	variable CUST_DETAILS
	variable GROUP
	variable LEG
	variable SELN

	if {[_smart_reset GROUP] || ![info exists GROUP($group_id,num_legs)]} {
		error\
			"group $group_id not described"\
			""\
			CUST_EVLVLLIMITS_NO_GROUP
	}

	_get_cust_details

	if {[info exists CUST_DETAILS(group_ev_lvl_limits,$group_id)]} {
		# Already worked out
		return $CUST_DETAILS(group_ev_lvl_limits,$group_id)
	}

	set cust_iv ""
	set cust_lg ""
	set cust_sf 9999

	# Don't know whether it might be best to pass in selections into here??
	for {set sg 0} {$sg < $GROUP($group_id,num)} {incr sg} {
		foreach leg $GROUP($group_id,$sg,legs) {
			foreach seln $LEG($leg,selns) {
				set oc_grp_id  $SELN($seln,ev_oc_grp_id)
				set type_id    $SELN($seln,ev_type_id)
				set class_id   $SELN($seln,ev_class_id)

				# Check for the most specific stake factor
				if {[info exists CUST_DETAILS(stake_scale,EVOCGRP,$oc_grp_id)]} {
					set sf $CUST_DETAILS(stake_scale,EVOCGRP,$oc_grp_id)
					set lg $CUST_DETAILS(liab_desc,EVOCGRP,$oc_grp_id)
				} elseif {[info exists CUST_DETAILS(stake_scale,TYPE,$type_id)]} {
					set sf $CUST_DETAILS(stake_scale,TYPE,$type_id)
					set lg $CUST_DETAILS(liab_desc,TYPE,$type_id)
				} elseif {[info exists CUST_DETAILS(stake_scale,CLASS,$class_id)]} {
					set sf $CUST_DETAILS(stake_scale,CLASS,$class_id)
					set lg $CUST_DETAILS(liab_desc,CLASS,$class_id)
				} else {
					set sf $CUST_DETAILS(max_stake_scale)
					set lg $CUST_DETAILS(liab_desc)
				}

				if {$sf < $cust_sf} {
					set cust_sf $sf
					set cust_lg $lg
				}

				if {[_get_config async_enable_intercept] == "Y"} {
					# Check for the most specific intercept value
					if {[info exists CUST_DETAILS(intercept_value,EVOCGRP,$oc_grp_id)]} {
						set iv $CUST_DETAILS(intercept_value,EVOCGRP,$oc_grp_id)
					} elseif {[info exists CUST_DETAILS(intercept_value,TYPE,$type_id)]} {
						set iv $CUST_DETAILS(intercept_value,TYPE,$type_id)
					} elseif {[info exists CUST_DETAILS(intercept_value,CLASS,$class_id)]} {
						set iv $CUST_DETAILS(intercept_value,CLASS,$class_id)
					} else {
						set iv $CUST_DETAILS(intercept_value)
					}
					if {$iv != "" && $cust_iv != ""} {
						set cust_iv [expr {$iv < $cust_iv ? $iv : $cust_iv}]
					} else {
						set cust_iv [expr {$cust_iv == "" ? $iv : $cust_iv}]
					}
				} else {
					set cust_iv ""
				}

				# The Market SF applies to customers with an SF <= 0.5 to protect
				# moneyback specials
				if {$cust_sf <= [OT_CfgGet MIN_CUST_SF_ON_BETS 0.5]} {
					set cust_sf [expr {$cust_sf * $SELN($seln,mkt_stk_factor)}]
				}
			}
		}
	}

	set CUST_DETAILS(group_ev_lvl_limits,$group_id) [list $cust_sf $cust_iv $cust_lg]

	return $CUST_DETAILS(group_ev_lvl_limits,$group_id)
}



# Go through all the event classes involved in this bet.
# For any class that doesn't have a row in tCustLimit. for this customer
# set the max_stake_scale to be tCustomer.max_stake_scale
# else set it to be tCustLimit.max_stake_scale.
# set cust_max_stk_scale to be the min of these values
# for example:
# tCustomer.max_stake_scale = 2
# And for this customer
# Football mss = 3
# Racing  mss = 10
# Single on Cricket cust_max_stk_scale = 2
# Single on Racing cust_max_stk_scale = 10
# Double on Basketball and Football cust_max_stk_scale = 2
# Double on Racing and Football cust_max_stk_scale = 3
#
proc ::ob_bet::_get_cust_scale_factor {group_id} {

        variable CUST_DETAILS
        variable GROUP
        variable LEG
        variable SELN

        if {[_smart_reset GROUP] || ![info exists GROUP($group_id,num_legs)]} {
                error\
                        "group $group_id not described"\
                        ""\
                        CUST_SCALEFACTOR_NO_GROUP
        }

        _get_cust_details

        if {[info exists CUST_DETAILS(group_cust_factor,$group_id)]} {
                #aready worked out
                return $CUST_DETAILS(group_cust_factor,$group_id)
        }

        set cust_sf 9999

        #don't know whether it might be best to pass in selections into here??
        for {set sg 0} {$sg < $GROUP($group_id,num)} {incr sg} {
                foreach leg $GROUP($group_id,$sg,legs) {
                        foreach seln $LEG($leg,selns) {
                                set class_id $SELN($seln,ev_class_id)
                                if {[info exists CUST_DETAILS(class_scale,$class_id)]} {
                                        set sf $CUST_DETAILS(class_scale,$class_id)
                                } else {
                                        set sf $CUST_DETAILS(max_stake_scale)
                                }

                                set cust_sf [expr {$sf < $cust_sf ? $sf : $cust_sf}]

                                # The Market SF applies to customers with an SF <= 0.5 to protect
                                # moneyback specials
                                if {$cust_sf <= [OT_CfgGet MIN_CUST_SF_ON_BETS 0.5]} {
                                        set cust_sf [expr {$cust_sf * $SELN($seln,mkt_stk_factor)}]
                                }
                        }
                }
        }

        set CUST_DETAILS(group_cust_factor,$group_id) $cust_sf

        return $cust_sf
}



#Lock the customer account to prevent any further account activities
#whilst we check the balance and place the bet.
proc ob_bet::_lock_acct {} {

	variable CUST

	if {!$CUST(check)} {
		#no need to lock the account
		return
	}

	#lock the account
	if {$CUST(anon)} {
		ob_db::exec_qry ob_bet::lock_term_acct $CUST(term_code)
	} else {
		ob_db::exec_qry ob_bet::lock_acct $CUST(cust_id)
	}
}



proc ob_bet::_get_cash_cust_details {} {

	variable CUST

	set rs [ob_db::exec_qry ob_bet::get_CB_details\
				$CUST(term_code)\
			    $CUST(ccy_code)]

	#for an anonymous customer we are expecting a betting
	#account and a cash account
	set n_rows [db_get_nrows $rs]
	if {$n_rows != 2} {
		error\
			"Could not retrieve account details for anonymous terminal"\
			""\
			CUST_INVALID_ANON_TERM
	}
	for {set i 0} {$i < 2} {incr i} {
		set acct_type [db_get_col $rs $i acct_type]

		if {$acct_type == "PUB"} {
			set CUST(acct_id) [db_get_col $rs $i acct_id]
		}
		if {$acct_type == "PRV"} {
			set CUST(bet_acct_id) [db_get_col $rs $i acct_id]
		}
	}

	set CUST(cust_id) [db_get_col $rs 0 cust_id]

	ob_db::rs_close $rs
}

::ob_bet::_log INFO "sourced cust.tcl"
