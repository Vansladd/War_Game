# ==============================================================
# $Id: pools.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
# (C) 2001 Orbis Technology Ltd. All rights reserved.
# ==============================================================
#---------------------------------------------------------------------------
# Functions to facilitate the placing of pools bets
#---------------------------------------------------------------------------
package require cust_flag
package require util_appcontrol

namespace eval OB_pools {

	variable pools_qrys_prepared 0
	variable tran_count 0
	variable pool_bet_map
	variable force_multiple 0
	variable pool_errors
	variable message_map
	variable reject_reason

	namespace export init
	namespace export start
	namespace export end
	namespace export abort
	namespace export add_pool_selns
	namespace export validate_bet
	namespace export place_bet
	namespace export complete_bet
	namespace export get_pool_info
	namespace export get_bet_info

	proc init {} {

		log 5 "OB_pools::init"

		variable tran_count
		variable pool_errors
		prepare_queries

		catch {unset pool_errors}
		set pool_errors(count) 0

		set force_multiple [OT_CfgGetTrue FORCE_MULTIPLE]
		set tran_count 0

		ob_cflag::init
	}

	proc log {level msg} {
		OT_LogWrite $level "pools: $msg"
	}

	proc prepare_queries {} {
		variable pools_qrys_prepared

		if {$pools_qrys_prepared == 1} {
			return
		}

		OB_db::db_store_qry get_pool_details {
			select

			p.pool_id,
			p.status pool_status,
			p.name pool,
			t.pool_type_id pool_type,
			t.num_legs,
			nvl(p.min_stake, t.min_stake) min_stake,
			nvl(p.max_stake, t.max_stake) max_stake,
			nvl(p.min_unit, t.min_unit) min_unit,
			nvl(p.max_unit, t.max_unit) max_unit,
			nvl(p.stake_incr, t.stake_incr) stake_incr,
			t.tax_rate,
			t.leg_type,
			t.bet_type,
			t.status type_status,
			t.all_up_avail,
			t.num_picks,
			t.min_runners,
			s.pool_source_id source,
			u.ccy_code,
			u.exch_rate pool_exch_rate,
			m.ev_mkt_id,
			m.leg_num,
			o.ev_oc_id,
			o.ev_id,
			o.ext_key ref_key,
			o.desc as o_desc,
			NVL(o.runner_num, -1) as runner_num,
			y.max_payout,
			NVL(t.tax_rate, NVL(k.tax_rate, NVL(e.tax_rate, NVL(y.tax_rate, 0)))) tax_rate,
			i.meeting_date,
			i.ev_meeting_id,
			k.status mkt_status,
			e.desc as e_desc,
			e.start_time,
			y.name as t_desc,
			case
				when pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off) = 'N'
				then 'Y'
				else 'N'
			end as started,
			case
				when
					k.status||o.status||e.status||y.status||c.status = 'AAAAA'
				then
					'A'
				else
					'S'
			end
				seln_status

			from

			tPool p,
			tPoolType t,
			tPoolSource s,
			tPoolMkt m,
			tEvMkt k,
			tEvOc o,
			tEv e,
			tEvType y,
			tEvClass c,
			tCCY u,
			outer tEvMeeting i

			where

			p.pool_id in (?, ?, ?, ?, ?, ?) and
			t.pool_type_id = p.pool_type_id	and
			t.pool_source_id = p.pool_source_id and
			s.pool_source_id = t.pool_source_id and
			u.ccy_code = s.ccy_code			and
			p.pool_id = m.pool_id	   and
			k.ev_mkt_id = m.ev_mkt_id       and
			o.ev_mkt_id = k.ev_mkt_id		and
			e.ev_id = k.ev_id				and
			y.ev_class_id = c.ev_class_id	and
			e.ev_type_id = y.ev_type_id		and
			i.ev_meeting_id = e.ev_meeting_id
		}

		OB_db::db_store_qry OB_pools::lock_acct {
                        update
                                tcustomer
                        set
                                bet_count = bet_count
                        where
                                cust_id = ?
                }

		OB_db::db_store_qry cust_info {
			select
				a.acct_id,
				a.acct_type,
				c.source,
				a.balance,
				a.credit_limit
			from
				tAcct a,
				tCustomer c
			where
				a.cust_id = c.cust_id
			and
				c.cust_id = ?
		}

		OB_db::db_store_qry ins_bet {
			execute procedure pInsPBet(
									p_bet_type          = ?,
									p_ev_meeting_id		= ?,
									p_desc				= ?,
									p_ipaddr			= ?,
									p_aff_id			= ?,
									p_source			= ?,
									p_cust_id			= ?,
									p_acct_id			= ?,
									p_unique_id			= ?,
									p_meeting_uid		= ?,
									p_num_selns			= ?,
									p_num_legs			= ?,
									p_num_lines			= ?,
									p_stake				= ?,
									p_ccy_stake			= ?,
									p_stake_per_line	= ?,
									p_max_payout		= ?,
									p_placed_by			= ?,
									p_call_id			= ?,
									p_slip_id			= ?,
									p_receipt_format	= ?,
									p_receipt_tag		= ?,
									p_pay_now			= 'Y',
									p_leg_no			= ?,
									p_part_no			= ?,
									p_ev_oc_id			= ?,
									p_ev_id				= ?,
									p_ev_mkt_id			= ?,
									p_pool_bet_id		= ?,
									p_pool_id			= ?,
									p_banker_info		= ?,
									p_allup				= ?,
									p_locale            = ?,
									p_rep_code			= ?,
									p_on_course_type		= ?
								)
		}

		OB_db::db_store_qry get_acct_info {
			select
				c.exch_rate cust_exch_rate,
				c.ccy_code
			from
				tAcct a,
				tCCY c
			where
				a.ccy_code = c.ccy_code
			and
				a.cust_id = ?
		}


		OB_db::db_store_qry complete_pending {
			execute procedure pPoolComplete(
							p_pool_bet_id = ?,
							p_action = ?,
							p_msg    = ?,
							p_do_tran = ?)
		}

		OB_db::db_store_qry gen_pool_uid {
			execute procedure pGenPoolUID(
							p_pool_id = ?,
							p_meeting_id = ?,
							p_pool_source_id = ?)
		}

		OB_db::db_store_qry update_attempts {
			update
				tPoolBetWaiting
			set
				num_tries = num_tries + 1,
				last_try  = current
			where
				pool_bet_id = ?
		}

		OB_db::db_store_qry set_pool_msg {
			update tPoolBetWaiting set
				 msg = ?
			where
				 pool_bet_id = ?
		}

		OB_db::db_store_qry get_pools {
			select
				o.ev_oc_id,
				p.pool_id,
				p.pool_type_id,
				p.pool_source_id
			from
				tEvOc o,
				outer (tPool p, tPoolMkt m)
			where
				p.pool_id = m.pool_id
			and
				m.ev_mkt_id = o.ev_mkt_id
			and
				p.pool_type_id = ?
			and
				o.ev_oc_id in (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		}

		OB_db::db_store_qry update_summary {
			execute procedure pUpdPoolSum(p_pool_id = ?,
										  p_ev_id = ?,
										  p_ev_oc_id = ?,
										  p_stake = ?)
		}


		OB_db::db_store_qry update_bet_count {
			execute procedure pUpdBetCount(p_pool_id = ?)
		}

		OB_db::db_store_qry debug {
			set debug file to '/tmp/db_mjc.log'
		}

		OB_db::db_store_qry get_evoc_desc {
			select
				desc
			from
				tevoc
			where
				ev_oc_id = ?
		}

		# OB_db::db_exec_qry debug

		set pools_qrys_prepared 1
	}

	proc pool_error {level type desc {params {}}} {
		variable pool_errors

		if {![info exists pool_errors(count)]} {
			set pool_errors(count) 0
		}
		set count $pool_errors(count)

		set lvl [expr {[info level] - 1}]
		set lvl_cmd [info level $lvl]

		set pool_errors($count,func) [lindex $lvl_cmd 0]
		set pool_errors($count,args) [lrange $lvl_cmd 1 end]

		switch $level {
			CRITICAL {
				set log_lvl 1
			}
			MINOR {
				set log_lvl 2
			}
			WARNING {
				set log_lvl 3
			}
			default {
				set log_lvl 5
			}
		}

		log $log_lvl "($type)\t $pool_errors($count,func): $desc"

		foreach var {type desc params} {
			set pool_errors($count,$var) [subst $$var]
		}

		incr pool_errors(count)
	}

	proc gen_pool_uid {pool_id {meeting_id ""} {source_id ""}} {
		if {[catch {set rs [OB_db::db_exec_qry gen_pool_uid $pool_id $meeting_id $source_id]} err]} {
			pool_error CRITICAL SQL "Unable to generate unique ID"
			return -1
		}

		set ret [db_get_coln $rs 0 0]
		OB_db::db_close $rs

		return $ret
	}

	proc get_pool_details {pool_ids {allow_guest_user N}} {
		global USER_ID

		variable pool_info

		log 50 "get_pool_details: getting details for pools: [join $pool_ids ", "]"

		if {$allow_guest_user=="N" || $allow_guest_user=="Y" && $USER_ID!=-1} {
			set msg "no rows"
			if {[catch {set rs [OB_db::db_exec_qry get_acct_info $USER_ID]} msg] ||
				[db_get_nrows $rs] != 1} {
				pool_error CRITICAL SQL "Unable to get account details for cust_id $USER_ID: $msg"
				return -1
			}
			set pool_info(cust_exch_rate) [db_get_col $rs 0 cust_exch_rate]
			set pool_info(cust_ccy_code)  [db_get_col $rs 0 ccy_code]
		}


		if {[catch {set rs [eval OB_db::db_exec_qry get_pool_details $pool_ids]} msg]} {
			pool_error CRITICAL SQL "Unable to pool details: $msg"
		}

		if {[set nrows [db_get_nrows $rs]] == 0} {
			pool_error WARNING NO_POOL "No pool details found"
			return -1
		}

		log 10 "get_pool_details: $nrows rows returned"

		for {set row 0} {$row < $nrows} {incr row} {
			set pool_id [db_get_col $rs $row pool_id]
			set pk "pool,$pool_id"

			if {![info exists pool_info($pk,pool_id)]} {
				# setup pool specifics
				foreach col {pool_id pool num_legs min_stake max_stake min_unit max_unit stake_incr\
								 tax_rate leg_type bet_type pool_status type_status pool_exch_rate \
								 source max_payout tax_rate pool_type ccy_code all_up_avail meeting_date \
								 ev_meeting_id min_runners num_picks} {
					set pool_info($pk,$col) [db_get_col $rs $row $col]
					log 30 "get_pool_details: pool_info($pk,$col) = $pool_info($pk,$col)"
				}
			} else {
				log 50 "get_pool_details: already got details for pool $pool_id"
			}

			# setup selection specifics
			set id [db_get_col $rs $row ev_oc_id]
			lappend pool_info($pk,selns) $id

			foreach col {ev_mkt_id leg_num ev_id seln_status started ref_key \
				mkt_status o_desc e_desc t_desc start_time runner_num
			} {
				set pool_info(seln,$id,$col) [db_get_col $rs $row $col]
				log 30 "get_pool_details: pool_info(seln,$id,$col) = $pool_info(seln,$id,$col)"
			}
		}

		return 1
	}

	proc start {{clean 1} {transactional Y}} {
		variable tran_count
		variable bet_info
		variable pool_info
		variable pool_errors


		if {$clean} {
			catch {unset pool_errors}
			set pool_errors(count) 0
			catch {array unset bet_info}
			catch {array unset pool_info}
		}

		if {$transactional=="Y"} {
			if {$tran_count > 0} {
				pool_error CRITICAL TRAN_STARTED "transaction already started"
			} else {
				OB_db::db_begin_tran
				incr tran_count
			}
		} else {OT_LogWrite 99 "**sluke** not bothering with TRANSACTIONS"}
	}

	proc end {{transactional Y}} {
		variable tran_count
		variable pool_errors

		if {$transactional == "Y"} {
			if {$tran_count != 1} {
				pool_error CRITICAL NO_TRAN "not in transaction"
			}

			OB_db::db_commit_tran
			set tran_count 0
		}
	}

	proc abort {} {
		variable tran_count
		variable pool_errors


		if {$tran_count != 1} {
			pool_error CRITICAL NO_TRAN "not in transaction"
		}

		OB_db::db_rollback_tran
		set tran_count 0
	}

	# adds the given selections for the given pool
	# can be called more than once but only to add
	# more id's to the same pool
	proc add_pool_selns {plist {floating 0} {allow_guest_user N}} {
		variable pool_info
		variable bet_info
		variable selns
		variable pool_errors

		catch {unset pool_info}
		catch {unset bet_info}

		set last_pos 1
		set selns(ids) {}
		set pool_info(pools) {}

		foreach pitem $plist {
			set pool_id [lindex $pitem 0]

			log 5 "add_pool_selns: adding pool $pool_id"
			lappend pool_info(pools) $pool_id
			set sidx 0

			# Loop through each selection disecting the ids
			foreach seln [lindex $pitem 1] {
				if {![regexp {([0-9]+)(B?)([0-9]*)} $seln all ev_oc_id banker banker_pos]} {
					pool_error MINOR SELN_PARSE "unable to parse selection: $seln"
					return -1
				}

				log 5 "add_pool_selns: adding $ev_oc_id to pool $pool_id at index $sidx"
				set selns($pool_id,$sidx,ev_oc_id) $ev_oc_id
				set selns($pool_id,$sidx,banker) $banker
				set selns($pool_id,$sidx,banker_pos) $banker_pos
				lappend bet_info(selns) $ev_oc_id
				incr sidx
			}
			set selns($pool_id,num_selns) $sidx
		}

		log 10 "add_pool_selns: getting pool details for pool_ids($pool_info(pools))"
		if {[get_pool_details $pool_info(pools) $allow_guest_user] == -1} {
			log 3 "could not get pool details for $pool_info(pools)"
			return -1
		}
		log 10 "add_pool_selns: getting pool details for pool_ids($pool_info(pools))"

		if {[llength $pool_info(pools)] > 1} {
			set bet_info(allup) "Y"
		} else {
			set bet_info(allup) "N"
		}

		# Get the details about the pool
		foreach pool_id $pool_info(pools) {
			set pk "pool,$pool_id"

			if {$pool_info($pk,pool_status) != "A"} {
				pool_error MINOR POOL_SUSP "This pool is currently suspended"
			}

			if {$pool_info($pk,type_status) != "A"} {
				pool_error MINOR TYPE_SUSP "This pool type is currently suspended"
			}

			for {set idx 1} {$idx <= $pool_info($pk,num_legs)} {incr idx} {
				set bet_info($pool_id,leg,$idx,banker_places) 0
				set bet_info($pool_id,leg,$idx,places) {}
			}
			set bet_info($pool_id,floating_bankers) $floating
		}
		log 10 "adding selections (sidx $sidx)"

		foreach pool_id $pool_info(pools) {
			set idx 0

			for {set sidx 0} {$sidx < $selns($pool_id,num_selns)} {incr sidx} {
				set ev_oc_id $selns($pool_id,$sidx,ev_oc_id)
				set sk "seln,$ev_oc_id"
				set ps "$pool_id,$sidx"

				log 10 "adding seln $ev_oc_id to pool $pool_id"

				# add errors to list before calling pool_error so we can add selection name
				set pools_errors [list]

				# Check selection is in given pool
				if {![info exists pool_info($sk,started)]} {
					lappend pools_errors {MINOR POOL_MISMATCH "selection $ev_oc_id$ev_oc_desc is not in pool $pool_id"}
				}

				# Check this market isn't suspended
				if {$pool_info($sk,mkt_status) == "S"} {
					lappend pools_errors {MINOR MKT_SUSP "market for selection $ev_oc_id$ev_oc_desc is suspended"}
				}

				# Check this hasn't started
				if {$pool_info($sk,started) == "Y"} {
					lappend pools_errors {MINOR STARTED "race for selection $ev_oc_id$ev_oc_desc has started"}
				}

				# Check this isn't suspended
				if {$pool_info($sk,seln_status) == "S"} {
					lappend pools_errors {MINOR SELN_SUSP "selection $ev_oc_id$ev_oc_desc is suspended"}
				}

				# Get the leg number and make sure our number of legs is correct
				if {[set leg_num $pool_info($sk,leg_num)] > $pool_info(pool,$pool_id,num_legs)} {
					lappend pools_errors {CRITICAL LEG_CHECK "selection $ev_oc_id$ev_oc_desc is in leg not in this pool"}
				}

				# if we have any errors get the selection description so we can
				# make nicer error messages and then add the errors properly
				if {[llength $pools_errors] > 0} {

					if {[catch {set rs [OB_db::db_exec_qry get_evoc_desc $ev_oc_id]} err]} {
						log 5 "query get_evoc_desc failed: $err"
						set ev_oc_desc ""
					} else {
						set ev_oc_desc " ([db_get_col $rs 0 desc])"
						db_close $rs
					}

					for {set err 0} {$err < [llength $pools_errors]} {incr err} {
						set level [lindex [lindex $pools_errors $err] 0]
						set code  [lindex [lindex $pools_errors $err] 1]
						set msg   [subst [lindex [lindex $pools_errors $err] 2]]
						pool_error $level $code $msg

					}

				}

				# Get the ev_id for this leg
				if {![info exists bet_info($pool_id,leg,$leg_num,ev_id)]} {
					set bet_info($pool_id,leg,$leg_num,ev_id) $pool_info(seln,$ev_oc_id,ev_id)
				}

				if {$selns($ps,banker) == "B"} {
					# If the position of the banker's not specified
					if {$selns($ps,banker_pos) == ""} {
						set selns($ps,banker_pos) $last_pos
					} else {
						if {$selns($ps,banker_pos) > $last_pos} {
							set last_pos $selns($ps,banker_pos)
						}
					}

					log 10 "adding banker to pool($pool_id), leg($leg_num), position($selns($ps,banker_pos))"
					lappend bet_info($pool_id,leg,$leg_num,bankers,$selns($ps,banker_pos)) $ev_oc_id
					if {$selns($ps,banker_pos) > $bet_info($pool_id,leg,$leg_num,banker_places)} {
						set bet_info($pool_id,leg,$leg_num,banker_places) $selns($ps,banker_pos)
					}
				} else {
					lappend bet_info($pool_id,leg,$leg_num,places) $ev_oc_id
				}
				log 10 "bet_info($pool_id,leg,$leg_num,places) is $bet_info($pool_id,leg,$leg_num,places) "

				incr idx
			}
		}

		log 10 [array get bet_info]
	}

	proc calc_perms {} {
		variable pool_info
		variable bet_info

		foreach pool_id $pool_info(pools) {
			set pk "pool,$pool_id"
			set no_perm 0

			# Setup the right function
			switch -- $pool_info($pk,leg_type) {
				O {
					if {$bet_info($pool_id,floating_bankers)} {
						set pfunc BMpermgen
					} else {
						set pfunc BMreal_permgen
					}
				}
				U {
					set pfunc BMpermgen
				}
				W -
				P {
					set pfunc {}
					set no_perm 1
					for {set leg 1} {$leg <= $pool_info($pk,num_legs)} {incr leg} {
						set bet_info($pool_id,leg,$leg,perms) $bet_info($pool_id,leg,$leg,places)
						set bet_info($pool_id,leg,$leg,num_lines) [llength $bet_info($pool_id,leg,$leg,perms)]
					}
				}
			}

			# Go through each leg
			for {set leg 1} {$leg <= $pool_info($pk,num_legs)} {incr leg} {
				set nbankers $bet_info($pool_id,leg,$leg,banker_places)

				log 5 "bet_info($pool_id,leg,$leg,places) = $bet_info($pool_id,leg,$leg,places)"
				if {$bet_info($pool_id,leg,$leg,places) == {}} {
					set places {}
				} else {
					if {$no_perm} {
						set places $bet_info($pool_id,leg,$leg,places)
					} else {
						log 5 "calc_perms: eval $pfunc \[expr $pool_info($pk,num_picks) - $nbankers\] $bet_info($pool_id,leg,$leg,places)"
						set places [eval $pfunc [expr {$pool_info($pk,num_picks) - $nbankers}] $bet_info($pool_id,leg,$leg,places)]
					}
				}

				log 5 "calc_perms: places = $places"
				log 5 "bet_info($pool_id,leg,$leg,banker_places) = $bet_info($pool_id,leg,$leg,banker_places)"

				set newperms {}
				if {$bet_info($pool_id,leg,$leg,banker_places) > 0} {
					if {$bet_info($pool_id,leg,$leg,banker_places) > 1} {
						# Work out all the banker permutations first
						set perms $bet_info($pool_id,leg,$leg,bankers,1)

						# Loop through each of the bankers
						for {set place 2} {$place <= $nbankers} {incr place} {
							set newperms {}

							foreach perm $perms {
								foreach banker $bet_info($pool_id,leg,$leg,bankers,$place) {
									# If this perm's not already got this banker then add it
									# This avoids duplicates
									if {[lsearch $perm $banker] == -1} {
										lappend newperms [concat $perm $banker]
									}
								}
							}
							set perms $newperms
						}

						# If this is an unordered leg (combinations) and more than 1 banker
						# place has been specified then we need to check for duplicates
						if {$pool_info($pk,leg_type) == "U" && $bet_info($pool_id,leg,$leg,banker_places) > 1} {
							set newperms {}
							foreach perm $perms {
								set nperm [lsort -integer -increasing $perm]
								if {[lsearch -exact $newperms $nperm] == -1} {
									lappend newperms $nperm
								}
							}
							set perms $newperms
						}
					} else {
						set perms [eval $pfunc $nbankers $bet_info($pool_id,leg,$leg,bankers,1)]
					}

					log 5 "calc_perms: perms = $perms"

					# Then, if there are any places, we add them now
					if {$places != {}} {
						set newperms {}
						foreach perm $perms {
							foreach place $places {
								if {[lsearch $perm $place] == -1} {
									lappend newperms [concat $perm $place]
								}
							}
						}
						set perms $newperms
					}

					# If we're a floater then we need to mix these little puppies up
					if {$bet_info($pool_id,floating_bankers)} {
						set newperms {}
						foreach perm $perms {
							log 5 "calc_perms: floating perm = $perm"
							set newperms [concat $newperms [eval BMreal_permgen $pool_info(pool,$pool_id,num_picks) $perm]]
						}
						set perms $newperms
					}
					set bet_info($pool_id,leg,$leg,perms) $perms
				} else {
					set bet_info($pool_id,leg,$leg,perms) $places
				}
				set bet_info($pool_id,leg,$leg,num_lines) [llength $bet_info($pool_id,leg,$leg,perms)]
				log 30 "set bet_info($pool_id,leg,$leg,num_lines) to $bet_info($pool_id,leg,$leg,num_lines) "
			}
		}
	}

	proc validate_bet {{type {SGL}}} {
		global BET_LINES
		global BETDEFN

		variable pool_info
		variable bet_info
		variable selns
		variable pool_errors

		set valid_types {AU2X1 AU3X1 AU2X3 AU3X7 AU3X3 AU3X4 DLEG TLEG}

		if {$bet_info(allup) == "Y" && [lsearch $valid_types $type] == -1} {
			pool_error CRITICAL NO_MULTIS "multi-pool bet must be allup"
			return -1
		}

		# Calculate the number of legs and the perms for each leg
		calc_perms

		set id 1
		set single_leg 1
		set single_picks 1

		# Loop through each of the pools that make up this bet
		foreach pool_id $pool_info(pools) {
			set pk "pool,$pool_id"

			if {$pool_info($pk,all_up_avail) == "N" && $bet_info(allup) == "Y"} {
				pool_error CRITICAL NO_ALLUPS "pool $pool_id may not be part of an allup"
				return -1
			}

			if {$pool_info($pk,num_legs) != 1} {
				set single_leg 0
			}

			if {$pool_info($pk,num_picks) != 1} {
				set single_picks 0
			}

			set layout $BET_LINES($pool_info($pk,bet_type))
			log 10 "layout is $layout"
			set new_layout {}
			foreach item $layout {
				set new_sub {}
				foreach sub_item $item {
					lappend new_sub $bet_info($pool_id,leg,$sub_item,num_lines)
				}
				lappend new_layout "([join $new_sub "*"])"
			}
			log 20 "validate_bet: pool($pool_id) line calculation: [join $new_layout "+"]"
			set bet_info($pool_id,num_lines) [eval expr [join $new_layout "+"]]
			set part($id) $bet_info($pool_id,num_lines)
			log 3 "validate_bet: pool($pool_id) number of lines: $bet_info($pool_id,num_lines)"
			incr id
		}

		set layout $BET_LINES($type)

		set num_pools [llength $pool_info(pools)]

		set bet_info(logging,horses) 0

		if {$single_leg == 1 && $single_picks == 1} {
			log 5 "logging: logging horses"
			set bet_info(logging,horses) 1
		}

		set gen_calc {}
		set tot_calc {}

		# This nasty bit of kit creates a generic function (2 actually) that when used with
		# the "NEXT BIT" calculates what portion of stake each selection in a leg uses.
		# This is so we can work out how much money's been placed on any particular selection
		foreach item $layout {
			set gen_sub {}
			foreach sub_item $item {
				lappend gen_sub "$\${array_name}(\[expr {(([expr $sub_item - 1] + \$inc) % $num_pools) + 1}\])"
			}
			lappend tot_calc "([join $gen_sub *])"
			log 50 "item = $item"
			if {[lsearch $item 1] != -1} {
				log 50 "adding item"
				lappend gen_calc "(([join $gen_sub *])/[llength $gen_sub].0)"
			}
		}

		set inc 0
		set tot_calc "([join $tot_calc +])"

		array set pcopy [array get part]
		set array_name pcopy

		# "NEXT BIT":
		set bet_info(num_lines) [eval expr [subst $tot_calc]]
 		log 3 "validate_bet: number of lines: $bet_info(num_lines)"

		set bet_info(bet_type) $type

		foreach pool $pool_info(pools) {
			set pool_info(pool,$pool,cash_mult) 0
		}

		foreach item $layout {
			set tot 1
			set pid [lindex $pool_info(pools) [expr {[lindex $item 0] - 1}]]
			log 5 "logging: pid = $pid"

			foreach subitem $item {
				set tot [expr {$tot * $part($subitem)}]
			}
			set pool_info(pool,$pid,cash_mult) [expr {$pool_info(pool,$pid,cash_mult) + $tot}]
			log 5 "logging: item $item = $tot lines"
		}

		foreach pid $pool_info(pools) {
			log 5 "logging $pid,cash_mult = $pool_info(pool,$pid,cash_mult)"
		}

	}

	# NOTE:
	# This version of calc_ccy_stake works out a stake in the punters
	# native currency that is an exact multiple of the unit stake when
	# converted to the pools currency. This is not necessarily what we
	# want so I've replaced it. I've left this version in for the time
	# being until I'm sure I don't want it any longer.


	# finds the appropriate USD unit stake and therefore the actual
	# stake in the placing currency.
	#proc calc_ccy_stake {native_unit_stake} {
	#	variable bet_info
	#	variable pool_info
	#	variable force_multple
	#
	#	set exch_rate [expr {$pool_info(pool_exch_rate) / $pool_info(cust_exch_rate)}]
	#
	#	# The stake we're aiming for
	#	set aim_stake [expr {$native_unit_stake * $bet_info(num_lines) * $exch_rate}]
	#
	#	if {$force_multiple} {
	#		set unit_mult [expr {floor($aim_stake / $pool_info(min_unit))}]
	#		set ccy_stake [expr {$unit_mult * $pool_info(min_unit)}]
	#		set native_stake [expr {ceil($ccy_stake / $exch_rate * 100) / 100}]
	#	} else {
	#		# Truncate to 2 decimal placed
	#		set ccy_stake $aim_stake
	#		set native_stake [expr {ceil($aim_stake * 100) / 100}]
	#	}
	#
	#	# Check our stake's not smaller than the smallest stake
	#	if {[expr {$ccy_stake / $bet_info(num_lines)}] < $pool_info(min_unit) ||
	#		$ccy_stake < $pool_info(min_stake)} {
	#		error "stake too small: ccy_stake = $ccy_stake"
	#	}
	#	if {$ccy_stake > $pool_info(max_stake)} {
	#		error "stake too large"
	#	}
	#
	#	set bet_info(ccy_stake) $ccy_stake
	#	set bet_info(native_stake) $native_stake
	#}

	proc calc_ccy_stake {ccy_unit_stake} {
		variable bet_info
		variable pool_info

		set pk "pool,[lindex $pool_info(pools) 0]"

		set ccy_stake [expr $ccy_unit_stake * $bet_info(num_lines)]

		# Check our stake limits
		if {$ccy_unit_stake < $pool_info($pk,min_unit) ||
			$ccy_stake      < $pool_info($pk,min_stake)} {
			pool_error CRITICAL SMALL_STAKE "stake too small" [list $pool_info($pk,min_unit) $pool_info($pk,ccy_code) $pool_info($pk,min_stake) $pool_info($pk,ccy_code)]
			return -1
		}

		if {$ccy_unit_stake > $pool_info($pk,max_unit) ||
			$ccy_stake      > $pool_info($pk,max_stake)} {
			pool_error CRITICAL LARGE_STAKE "stake too large" [list $pool_info($pk,max_unit) $pool_info($pk,ccy_code) $pool_info($pk,max_stake) $pool_info($pk,ccy_code)]
			return -1
		}

		# check the the stake increment matches those required
		if {$pool_info($pk,stake_incr) != ""} {
			set v [expr { ($ccy_unit_stake - $pool_info($pk,min_stake)) / $pool_info($pk,stake_incr)}]
			set epsilon 1e-6
			# odd looking fix for floating point error which may occur at anytime
			if {abs([expr {round($v)}] - $v) > $epsilon} {
				pool_error CRITICAL STAKE_INCREMENT "stake increment is the wrong size" [list $pool_info($pk,stake_incr) $pool_info($pk,ccy_code)]
				return -1
			}
		}

		# get customer's native stake
		set exch_rate    [expr {$pool_info($pk,pool_exch_rate) / $pool_info(cust_exch_rate)}]
		set native_stake [expr {$ccy_stake / $exch_rate}]
		set native_stake [expr {round($native_stake * 100) / 100.0}]

		set bet_info(ccy_stake)    $ccy_stake
		set bet_info(native_stake) $native_stake
	}

	# Converts a stake in the customer's currency to a stake in the pool's currency
	# Note that we have to do some jiggery pokery as a bet of £10 may map to both
	# $14.55 and $14.56 but only $14.56 is a valid bet.
	proc convert_stake_cust_to_pool_accurate {stake} {
		variable pool_info
		variable bet_info

		set pk "pool,[lindex $pool_info(pools) 0]"

		# Convert currency from customer's currency to pool's currency
		set stake_per_line [convert_stake_cust_to_pool $stake]

		# Paranoia - if there are 0 lines, we'll hit divide-by-zero errors in our
		# calculations, so just return the converted stake without checking the
		# limits as the stake is invalid regardless.
		if {$bet_info(num_lines) == 0} {
			return $stake_per_line
		}

		# Work out the nearest valid stakes
		set valid_stakes       [_get_nearest_valid_pool_stakes $stake_per_line]
		set stake_rounded_down [lindex $valid_stakes 0]
		set stake_rounded_up   [lindex $valid_stakes 1]

		# Convert various stakes from pool's currency to customer's currency
		set stake_rounded_down_cust [convert_stake_pool_to_cust $stake_rounded_down]
		set stake_rounded_up_cust   [convert_stake_pool_to_cust $stake_rounded_up]

		# The stake is valid
		if {$stake_rounded_down_cust == $stake} {
			return $stake_rounded_down;
		}

		# The stake is also valid
		if {$stake_rounded_up_cust == $stake} {
			return $stake_rounded_up;
		}

		# The stake is invalid - it doesn't matter whether we round up or down
		return $stake_per_line
	}

	# Given a stake in the pool's currency, this calculates the nearest valid
	# stakes above and below the value.
	proc _get_nearest_valid_pool_stakes {stake_per_line} {
		variable bet_info
		variable pool_info

		set pk "pool,[lindex $pool_info(pools) 0]"
		set stake_incr [expr double($pool_info($pk,stake_incr))]
		set max_unit   [expr double($pool_info($pk,max_unit))]
		set min_unit   [expr double($pool_info($pk,min_unit))]
		set max_stake  [expr double($pool_info($pk,max_stake))]
		set min_stake  [expr double($pool_info($pk,min_stake))]
		set num_lines  [expr double($bet_info(num_lines))]

		# Calculate the lower (or equal to) amount
		set stake_rounded_down [_get_lower_valid_pool_stake $stake_per_line $stake_incr]

		# Calculate the higher amount
		set stake_rounded_up [expr $stake_rounded_down + $stake_incr]

		# Before we apply the min and max limits, we raise/lower the limits based
		# off the total stake limits.
		set max_total_unit [expr round(($max_stake / $num_lines) * 100) / 100.0]
		set min_total_unit [expr round(($min_stake / $num_lines) * 100) / 100.0]
		set min_unit [max $min_total_unit $min_unit]
		set max_unit [min $max_total_unit $max_unit]

		# Apply min and max limits to unit stake
		set stake_rounded_down [min $stake_rounded_down $max_unit]
		set stake_rounded_down [max $stake_rounded_down $min_unit]
		set stake_rounded_up   [min $stake_rounded_up   $max_unit]
		set stake_rounded_up   [max $stake_rounded_up   $min_unit]

		return [list $stake_rounded_down $stake_rounded_up $min_unit $max_unit]
	}

	proc _get_lower_valid_pool_stake {stake unit} {
		if {$unit == 0} {
			return $stake
		}
		return [expr $unit * floor(double($stake)/double($unit))];
	}

	# Convert a stake amount from the customer's currency to the pool's currency
	proc convert_stake_cust_to_pool {stake} {
		variable pool_info
		set pk "pool,[lindex $pool_info(pools) 0]"
		set exch_rate [expr {$pool_info(cust_exch_rate) / $pool_info($pk,pool_exch_rate)}]
		return [convert_stake $stake $exch_rate]
	}

	# Convert a stake amount from the pool's currency to the customer's currency
	proc convert_stake_pool_to_cust {stake} {
		variable pool_info
		set pk "pool,[lindex $pool_info(pools) 0]"
		set exch_rate [expr {$pool_info($pk,pool_exch_rate) / $pool_info(cust_exch_rate)}]
		return [convert_stake $stake $exch_rate]
	}

	proc convert_stake {stake exch_rate} {
		set native_stake [expr {$stake / $exch_rate}]
		return [expr {round($native_stake * 100) / 100.0}]
	}

	proc place_bet {unit uid {bet_msg ""} {meeting_id ""} {channel "I"} {operator ""} {call_id ""} {slip_id ""} {term_code ""} {application "default"}} {

		global BET_LINES
		global BETDEFN
		global PB_OVERRIDES

		global REMOTE_ADDR USER_ID
		variable pool_info
		variable bet_info
		variable pool_errors

		if {[OB_login::ob_is_guest_user]} {
			pool_error CRITICAL SQL "User must be logged in to place pools bet"
 			return -1
		}

		set source $pool_info(pool,[lindex $pool_info(pools) 0],source)

		# Authenticate the customer for betting in TRNI or Tote
		if {$source == "T" || $source == "U"} {
			set res [authenticate_pools $source "bet" $channel $application]
			if {$res != "OK"} {
				# Tote or TRNI is banned for this channel in this country
				if { $res == "BANNED_ITEM"} {
					pool_error CRITICAL "BANNED_ITEM" "This item is banned for this country"
				} else {
					pool_error CRITICAL SQL "unknown error"
				}
				ob_log::write INFO {Authenticate failed: $res}
				return -1
			}
		}

		# lock the account before finding the balance etc.
		OB_db::db_exec_qry OB_pools::lock_acct $USER_ID

		# Get customer info
		if {[catch {set res [OB_db::db_exec_qry cust_info $USER_ID]} err]} {
			pool_error CRITICAL SQL "error getting customer info: $err"
			return -1
		}
		if {[db_get_nrows $res] != 1} {
			pool_error CRITICAL ROW_COUNT "expected 1 row returned while getting customer info for cust_id $USER_ID"
			return -1
		}

		set acct_id [db_get_col $res 0 acct_id]

		# should be set to app not customer?
		#	set source [db_get_col $res 0 source]

		set balance [db_get_col $res 0 balance]
		set credit_limit [db_get_col $res 0 credit_limit]
		set acct_type [db_get_col $res 0 acct_type]

		# get our stake
		if {[calc_ccy_stake $unit]==-1} {
			return -1
		}

		# Soft credit limits
		set soft_credit_limit [expr {
			$acct_type != "CDT" ? 0.0 : (
				$credit_limit == "" ? "" : (
					$credit_limit * (
						[OT_CfgGet SOFT_CREDIT_LIMITS 0] ?
						(1.0 + [ob_control::get credit_limit_or] / 100.0) :
						1.0
					)
				)
			)
		}]

		#
		# Handle account limit overrides HERE, don't check for retail slips
		#
		# Need to set pb_real 1 so that pb_err knows we are really placing
		# a bet to handle overrides correctly

		# log 40 "**SA** Set pb_real 1 - Hack to allow overrides to work using pb_err"
		# set OB_placebet::pb_real 1

		if {$slip_id == ""} {
			# Use check override arg for pb_err instead
			set err_msg "Insufficient funds to place bet"
			if {$acct_type=="CDT"} {
				if {[expr {$balance + $soft_credit_limit}] < $bet_info(native_stake)} {
					if {[OT_CfgGet AVOID_PB2 0] == 0} {
						if {[OT_CfgGet POOLS_DONT_CHECK_PLACEBET2 0] || [pb_err ERR CREDIT $err_msg BET 0 () () 1] == 1} {
							pool_error CRITICAL CREDIT "insufficient funds in your account to place bet"
							return -1
						}
					} else {
						pool_error CRITICAL CREDIT "insufficient funds in your account to place bet"
						return -1
					}
				}
			} else {
				log  10 "AVAILABLE: $balance"
				if {$balance < $bet_info(native_stake)} {
					#
					# If we're overriding the payment gateway no socket error
					# Just let the amount go negative
					#
					if {($acct_type!="DBT" || [OT_CfgGet PMT_DBT_BAL_TO_ZERO 1]==1) && [OT_CfgGet AVOID_PB2 0] == 0} {
						if {[OT_CfgGet POOLS_DONT_CHECK_PLACEBET2 0] || [pb_err ERR LOW_FUNDS $err_msg BET 0 () () 1]==1} {
							pool_error CRITICAL CREDIT "insufficient funds in your account to place bet"
							return -1
						}
					} else {
						pool_error CRITICAL CREDIT "insufficient funds in your account to place bet"
						return -1
					}
				}
			}
		}

		foreach name [array names bet_info] {
			log 50 "place_bet: $name = $bet_info($name)"
		}

		# For non allup bets there is only going to be one
		# pool so use those details here
		set pool_id [lindex $pool_info(pools) 0]
		set pk "pool,$pool_id"
		log 50 "place_bet: pool_id = $pool_id"


		# Generate a new meeting_uid for the bet. For MJC, it is not
		# dependent on the pool but on the meeting.
		if {[OT_CfgGet OPENBET_CUST ""] == "SLOT" || [OT_CfgGet OPENBET_CUST ""] == "MJC"} {
			set bet_info(pool_uid) [gen_pool_uid "" $meeting_id "M"]
		} else {
			set bet_info(pool_uid) [gen_pool_uid $pool_id]
			set meeting_date ""
		}

		# !! Check bets going in correctly for MJC / SLOT with the right account flag.
		if {[OT_CfgGet OPENBET_CUST ""] == "SLOT" || [OT_CfgGet OPENBET_CUST ""] == "MJC"} {
			if {[OT_CfgGet OPENBET_CUST ""] == "MJC"} {
				set isMJCAccount 0
			} else {
				set isMJCAccount 1
			}
			set pool_info(bet_msg) "$bet_info(pool_uid):$isMJCAccount:$pool_info(bet_msg)"
		}

		# get the info we need for the remote system
		# store it with the bet incase we need it later

		if {$source == "T" && $bet_msg == ""} {
			set pool_info(bet_msg) [build_trni_msg]
		} elseif {$source == "U"} {
			set pool_info(bet_msg) ""
		} else {
			set pool_info(bet_msg) $bet_msg
		}

		# ins_bet inserts the bet into the pending tables with the
		# pending_status set to 'S' (sent) which means that the
		# jobs checking for pending bets doesn't try to send it
		# until we've finished with it here.

		set qry_base OB_db::db_exec_qry
		lappend qry_base ins_bet
		lappend qry_base $bet_info(bet_type)
		lappend qry_base $pool_info(pool,$pool_id,ev_meeting_id)
		lappend qry_base $pool_info(bet_msg)
		lappend qry_base [reqGetEnv REMOTE_ADDR]
		lappend qry_base [get_cookie AFF_ID]
		lappend qry_base $channel
		lappend qry_base $USER_ID
		lappend qry_base $acct_id
		lappend qry_base $uid
		lappend qry_base $bet_info(pool_uid)
		lappend qry_base [llength $bet_info(selns)]
		lappend qry_base $pool_info($pk,num_legs)
		lappend qry_base $bet_info(num_lines)
		lappend qry_base $bet_info(native_stake)
		lappend qry_base $bet_info(ccy_stake)
		lappend qry_base [expr {$bet_info(ccy_stake) / $bet_info(num_lines)}]
		lappend qry_base $pool_info($pk,max_payout)
		lappend qry_base $operator
		lappend qry_base $call_id
		lappend qry_base $slip_id
		lappend qry_base [OT_CfgGet BET_RECEIPT_FORMAT 0]
		lappend qry_base [OT_CfgGet BET_RECEIPT_TAG ""]

		set pending_id ""

		if {$bet_info($pool_id,floating_bankers)} {
			set prefix "M"
		} else {
			set prefix ""
		}

		set fake_leg 1

		# Is the locale configured.
		if {[lsearch [OT_CfgGet LOCALE_INCLUSION] BET_POOLS] > -1} {
			set locale [app_control::get_val locale]
		} else {
			set locale ""
		}

		set rep_code [reqGetArg rep_code]
		set on_course_type [reqGetArg course]


		foreach pool_id $pool_info(pools) {
			set pk "pool,$pool_id"

			for {set leg 1} {$leg <= $pool_info($pk,num_legs)} {incr leg} {
				set qry_seln $qry_base
				lappend qry_seln $fake_leg

				set part 1

				# Add the bankers
				for {set place 1} {$place <= $bet_info($pool_id,leg,$leg,banker_places)} {incr place} {
					foreach banker $bet_info($pool_id,leg,$leg,bankers,$place) {
						set qry $qry_seln

						lappend qry $part
						lappend qry $banker
						lappend qry $pool_info(seln,$banker,ev_id)
						lappend qry $pool_info(seln,$banker,ev_mkt_id)
						lappend qry $pending_id
						lappend qry $pool_id
						lappend qry "B${prefix}$place"
						lappend qry $bet_info(allup)
						lappend qry $locale
						lappend qry $rep_code
						lappend qry $on_course_type

						log 50 "place_bet: query = $qry"

						if {[catch {set rs [eval $qry]} msg]} {
							pool_error CRITICAL SQL "unable to add selection: $msg"
							return -1
						}

						if {[db_get_nrows $rs] != 1} {
							pool_error CRITICAL ROW_COUNT "only 1 row should have been added"
							return -1
						}

						set pending_id [db_get_coln $rs 0 0]
						OB_db::db_close $rs
						incr part
					}
				}

				# Add the places
				foreach place $bet_info($pool_id,leg,$leg,places) {
					set qry $qry_seln

					lappend qry $part
					lappend qry $place
					lappend qry $pool_info(seln,$place,ev_id)
					lappend qry $pool_info(seln,$place,ev_mkt_id)
					lappend qry $pending_id
					# If this is an allup we stick a null in the pool_id
					lappend qry $pool_id
					lappend qry ""
					lappend qry $bet_info(allup)
					lappend qry ""
					lappend qry $rep_code
					lappend qry $on_course_type

					log 50 "place_bet: query = $qry"

					if {[catch {set rs [eval $qry]} msg]} {
						pool_error CRITICAL SQL "unable to add selection: $msg"
						return -1
					}

					if {[db_get_nrows $rs] != 1} {
						pool_error CRITICAL ROW_COUNT "only 1 row should have been added"
						return -1
					}

					set pending_id [db_get_coln $rs 0 0]
					OB_db::db_close $rs
					incr part
				}
				incr fake_leg
			}
		}



		if { [OT_CfgGetTrue CAMPAIGN_TRACKING] } {
			ob_camp_track::record_camp_action $USER_ID "BET" "POOL" $pending_id
		}

		return $pending_id
	}

	proc complete_bet {pending_id {manual 0} {transactional Y}} {

		global USER_ID

		variable pool_info
		variable selns
		variable bet_info
		variable pool_errors
		variable reject_reason

		set bet_id -1

		# take the source from the initial pool - we're
		# only supporting multiples from the same source!
		set source $pool_info(pool,[lindex $pool_info(pools) 0],source)

		# check if pools bet is to be placed manually
		# config setting to be string of tpoolsource.pool_source_id's
		# eg. if tote and trni to be placed manually then POOL_SOURCE_PLACED_MANUALLY = 'UT'
		if {[string first $source [OT_CfgGet POOL_SOURCE_PLACED_MANUALLY ""]] >= 0} {
			set manual 1
		}

		if {[OT_CfgGetTrue POOL_TESTING] || $manual} {
				log 3 "pools: completing pool bet because either the mode is pools testing or the bet should be completed manually"

				if {[catch {OB_db::db_exec_qry complete_pending $pending_id A "" $transactional} err]} {
					pool_error CRITICAL SQL "completing pending bet $pending_id: $err"
					return -1
				}

				set bet_id $pending_id

				set tot 0.0
				set stake 0.0

				foreach pid $pool_info(pools) {
					OB_db::db_exec_qry update_bet_count $pid
				}

				return $bet_id
		# end of testing
		}

		# Attempt to send bet to the pool
		switch -exact -- $source {
			"T" {
				set result [trni_complete $pending_id]
				set msg [lindex $result 1]
				set result [lindex $result 0]
			}
			"U" {
				set result [tote_complete $pending_id]
				set msg [lindex $result 1]
				set msg [map_msg $msg]
				set result [lindex $result 0]
			}
			"M" {
				log 10 "Starting mjc_complete ($pending_id)"
				set result [mjc_complete $pending_id]
				set msg ""
			}
			default {
				pool_error MINOR UNKNOWN_SOURCE "unknown pool source therefore bet not completed but still pending: $pending_id"
			}
		}

		switch -exact -- $result {
			"REJECT" {
				if {[catch {OB_db::db_exec_qry complete_pending $pending_id X $msg $transactional} err]} {
					error "complete_bet: rejecting pending bet $pending_id: $err"
				}
				set bet_id REJECT
				set reject_reason $msg
			}
			"PENDING" {
				set bet_id PENDING
				if {[catch {OB_db::db_exec_qry update_attempts $pending_id} err]} {
					OT_LogWrite 3 "complete_bet: unable to update completion attempts"
				}
			}
			"TIMEOUT" {
				set bet_id PENDING
				if {[catch {OB_db::db_exec_qry update_attempts $pending_id} err]} {
					OT_LogWrite 3 "complete_bet: unable to update completion attempts"
				}
			}
			"ERROR" {
				set bet_id PENDING
				if {[catch {OB_db::db_exec_qry update_attempts $pending_id} err]} {
					OT_LogWrite 3 "complete_bet: unable to update completion attempts"
				}
				OT_LogWrite 2 "complete_bet: error sending bet: $OB_InfoText::err_msg"
			}
			"OK" {
				if {[catch {set rs [OB_db::db_exec_qry complete_pending $pending_id A "" $transactional]} err]} {
					error "complete_bet: completing pending bet $pending_id: $err"
				}
				set bet_id $pending_id
			}
			default {
				pool_error MINOR UNKNOWN_SOURCE "unknown pool type source"
				if {[catch {OB_db::db_exec_qry update_attempts $pending_id} err]} {
					pool_error WARNING SQL "unable to update completion attempt: $err"
				}
			}
		}

		# freebet triggers
		set trig_list {POOLBET}
		log 3 "Sending $trig_list to FreeBets"

		set in_trans 1
		if {$transactional} {
			set in_trans 0
		}

		# Only trigger the freebet is we completed the pools bet.
		#
		if {$result == "OK"} {
			if {[OB_freebets::check_action\
				$trig_list\
				$USER_ID\
				[get_cookie AFF_ID]\
				$bet_info(ccy_stake)\
				$bet_info(selns)\
				""\
				""\
				""\
				$bet_id\
				"SPORTS"\
				""\
				$in_trans] != 1} {
					log 3 "Check action $trig_list failed for bet_id $bet_id"
			}
		}

		# If we failed to place this bet, increase the failed bet count.
		#
		if {$result != "OK"} {
			if {[catch {
				# Don't forget to insert the description into tCustFlagDesc.
				#
				set pool_bet_fails [ob_cflag::get "POOL_BET_FAILS" $USER_ID]
				if {$pool_bet_fails == ""} {
					set pool_bet_fails 0
				}
				incr pool_bet_fails
				ob_cflag::set_value "POOL_BET_FAILS" $pool_bet_fails $USER_ID $in_trans
			} msg]} {
				OT_LogWrite 2 "Failed to increment failed pool bet count: $msg"
			}
		}

		return $bet_id
	}

	# TRNI does not support all ups so therefore all the detail is held
	# in one pool
	proc build_trni_msg {} {

		variable pool_info
		variable bet_info

		set pool_id [lindex $pool_info(pools) 0]

		set pk "pool,$pool_id"

		set pool_type $pool_info($pk,pool_type)

		if {[lsearch {EXA QIN TRI SPR} $pool_type] >= 0} {
			set place_slash 1
			set trailing_slash 0
		} else {
			set place_slash 0
			set trailing_slash 1
		}

		set legs {}

		OT_LogWrite 5 "num_legs $pool_info($pk,num_legs)"
		for {set leg 1} {$leg <= $pool_info($pk,num_legs)} {incr leg} {
			OT_LogWrite 5 "places $bet_info($pool_id,leg,$leg,places)"
			OT_LogWrite 5 "banker places $bet_info($pool_id,leg,$leg,banker_places)"
			if {$bet_info($pool_id,leg,$leg,banker_places) == 0} {
				switch -- $pool_type {
					"EXA" {
						set pool_type EXX
						set place_slash 0
						set trailing_slash 1
					}
					"TRI" {
						set pool_type TRX
						set place_slash 0
						set trailing_slash 1
					}
					"SPR" {
						set pool_type SPX
						set place_slash 0
						set trailing_slash 1
					}
					"QIN" {
						set pool_type QNX
						set place_slash 0
						set trailing_slash 1
					}
				}
			}

			set selns $bet_info($pool_id,leg,$leg,places)

			for {set i 0} {$i < $bet_info($pool_id,leg,$leg,banker_places)} {incr i} {
				lappend selns $bet_info($pool_id,leg,$leg,bankers,[expr {$i + 1}])
			}

			foreach place $selns {

				foreach seln $place {

					# set reg {([A-Z]{3})([0-9]{2})([0-9]{2})}
					# Change regex to allow alpha-numeric track codes, as per
					# http://shared.orbis/orbis/Customers/TRNI/USRAW Spec.doc section 3.2.1
					set reg {(\w{3})(\d{2})(\d{2})}

					set ref $pool_info(seln,$seln,ref_key)

					if {[regexp -- $reg $ref match meeting race runner] == 0} {
						error "trni_complete: parsing selection code: $pool_info(seln,$place,ref_key)"
					}
					OT_LogWrite 5 "meeting = $meeting, race = $race, runner = $runner"
					set race   [string trimleft $race 0]
					set runner [string trimleft $runner 0]

					lappend legs $race
					append leg_info($race) [format "%02d" $runner]
				}

				if {$place_slash} {
					append leg_info($race) "/"
				}
			}
		}

		set legs [lsort -integer -increasing -unique $legs]

		set leg_data ""

		foreach race $legs {
			append leg_data "$leg_info($race)"
			if {$trailing_slash} {
				append leg_data "/"
			}
		}

		OT_LogWrite 9 "leg_data $leg_data"

		set stake_per_line [split [format "%0.2f" [expr {$bet_info(ccy_stake) / $bet_info(num_lines)}]] "."]
		set u_doll [lindex $stake_per_line 0]
		set u_cent [lindex $stake_per_line 1]
		set total_stake [split [format "%0.2f" $bet_info(ccy_stake)] "."]
		set t_doll [lindex $total_stake 0]
		set t_cent [lindex $total_stake 1]

		# If the bet is an exacta, a quinella, a trifecta or a superfecta
		# the the number of legs is actually the number of winning positions
		if {$pool_type == "EXA" ||
			$pool_type == "QIN" ||
			$pool_type == "TRI" ||
			$pool_type == "SPR"} {
			set num_legs $pool_info(pool,$pool_id,num_picks)
		} else {
			set num_legs $pool_info($pk,num_legs)
		}
		return [list $bet_info(pool_uid) $meeting\
					 [lindex $legs 0] $pool_type $u_doll $u_cent \
					 $num_legs $leg_data $t_doll $t_cent]
	}

	#
	# place the TRNI bet in the pool
	#
	# originally each appserver tried to place it's own bets in the pool
	# now this should be done through a proxy as TRNI does not handle
	# multiple concurrent bets well.
	#
	# This code supports both methods and is switched by TRNI_USE_BET_PROXY
	# config variable. the default is to use the proxy
	#

	proc trni_complete {pending_id} {
		variable pool_info

		if {[OT_CfgGet TRNI_USE_BET_PROXY 0] == 1} {
			set ret [trni_complete_proxy $pending_id $pool_info(bet_msg)]
		} else {
			set ret [trni_complete_infotext $pending_id]
		}

		return $ret
	}


	proc trni_complete_proxy {pending_id msg} {

		set host [OT_CfgGet TRNI_BET_PROXY_HOST]
		set port [OT_CfgGet TRNI_BET_PROXY_PORT]


		if {[catch {set sock [socket_timeout $host $port 1000]} err_msg]} {
			log 3 "Failed to connect to TRNI bet proxy : $err_msg"
			return [list REJECT "failed to connect to TRNI bet proxy"]
		}

		if {[catch {

			OT_LogWrite 5 "sending msg to TRNI proxy $msg"

			puts $sock [list $pending_id $msg]
			set ret_list [read_timeout $sock 15000]

			OT_LogWrite 5 "Proxy returned: $ret_list"


			if {[llength $ret_list] != 2} {
				OT_LogWrite 3 "TRNI bet proxy returned an invalid response: $ret_list"
				set ret_list [list REJECT "This pool is currently not available for betting.  Please try again later"]
			}

			switch -- [lindex $ret_list 0] {
				"OK" -
				"REJECT" -
				"ERROR" {
					# do nothing
				}
				"TIMEOUT" {
					# do normal reject
					OT_LogWrite 3 "TRNI bet proxy timed out."
					set ret_list [list REJECT "This pool is currently not available for betting.  Please try again later"]
				}
				default {
					OT_LogWrite 3 "TRNI bet proxy returned an invalid return code: [lindex $ret_list 0]"
					set ret_list [list REJECT "This pool is currently not available for betting.  Please try again later"]
				}
			}


		} err]} {
			OT_LogWrite 3 "error while hadling TRNI proxy response: $err"
			set ret_list [list REJECT "Failed to connect to TRNI bet proxy"]
		}

		close $sock

		return $ret_list
	}

	proc socket_timeout {host port timeout} {
		variable connected

		set connected ""
		set id [after $timeout {set OB_pools::connected "TIMED_OUT"}]

		set sock [socket -async $host $port]

		fileevent $sock w {set OB_pools::connected "OK"}
		vwait OB_pools::connected

		after cancel $id
		fileevent $sock w {}

		if {$connected == "TIMED_OUT"} {
			catch {close $sock}
			error "Connection attempt timed out after $timeout ms"

		} else {
			fconfigure $sock -blocking 0
			if [catch {gets $sock a}] {
				close $sock
				error "Connection failed"
			}
			fconfigure $sock -blocking 1 -buffering line
		}

		return $sock
	}


	proc read_timeout {sock timeout} {

		variable trni_msg_timer

		fconfigure $sock -blocking 0 -buffering line
		fileevent $sock r {set OB_pools::trni_msg_timer OK}

		set id [after $timeout {set OB_pools::trni_msg_timer "TIMED_OUT"}]
		vwait OB_pools::trni_msg_timer
		fileevent $sock r {}
		after cancel $id

		if { $trni_msg_timer == "TIMED_OUT" } {
			OT_LogWrite 3 "read_timeout timed out"
			return [list TIMEOUT blah]
		}

		return [gets $sock]
	}

	proc trni_complete_infotext {pending_id} {

		variable bet_info
		variable pool_info

		set pool_id $pool_info(pools)
		set pk      "pool,$pool_id"

		# Heavy error shit going down here to make sure we close sockets
		# etc. Don't want 'em lying about all over the place.
		set ret OK

		if {[OB_InfoText::connect [OT_CfgGet TRNI_SERVER]] != 1} {
			log 3 "trni_complete: unable to connect to server [OT_CfgGet TRNI_SERVER]: $OB_InfoText::err_msg"
			return REJECT
		}

		if {[catch {
			set ret [OB_InfoText::sign_on [OT_CfgGet TRNI_ACCTNO] [OT_CfgGet TRNI_PIN] $pool_info($pk,meeting_date)]
		} err]} {
			log 3 "trni_complete: error connecting to server: $err"
			catch {OB_InfoText::disconnect} err
			return REJECT
		}

		if {$ret == "OK"} {
			set ret [eval "OB_InfoText::bet_sell $pool_info(bet_msg)"]
			set bet_info(pool_error) $OB_InfoText::err_msg
		}

		if {[catch {
			OB_InfoText::sign_off
		} err]} {
			# If got this far assume bet placed but warn
			log 3 "trni_complete: error signing off: $err"
		}

		if {[catch {
			OB_InfoText::disconnect
		} err]} {
			# If got this far assume bet placed but warn
			log 3 "trni_complete: error disconnecting: $err"
		}

		return [list $ret $OB_InfoText::cust_msg]
	}


	proc tote_complete {pending_id} {
		# should return either "OK" or "REJECT msg" where msg will be mapped by map_msg before being put in db


		set host [OT_CfgGet TOTE_FEED_HOST]
		set port [OT_CfgGet TOTE_FEED_PORT]

		if {[catch {set sock [socket_timeout $host $port 1000]} err_msg]} {
			log 3 "Failed to connect to Tote feed: $err_msg"
			return [list REJECT  TOTE_FAILED_CONNECT]
		}

		if {[catch {

			OT_LogWrite 5 "sending msg to Tote feed: $pending_id"

			puts $sock $pending_id
			set ret_list [read_timeout $sock [OT_CfgGet TOTE_FEED_TIMEOUT]]

			# We can expect $ret_list to be one of 3 things:
			# a. accepted bet: 'OK'
			# b. rejected bet: [list REJECT [list $code $text]] e.g. 'REJECT {101 {pool suspended}}'
			# c. we had a timeout in read_timeout: 'TIMEOUT blah'

			OT_LogWrite 5 "Tote feed returned: $ret_list"

			switch -- [lindex $ret_list 0] {
				"OK" {
					# do nothing
				}
				"REJECT" {
					OT_LogWrite 4 "Tote rejected bet because: [lindex $ret_list 1]"
					set error_code [lindex [lindex $ret_list 1] 0]
					set ret_list [list REJECT "TOTE_CODE_$error_code"]
				}
				"TIMEOUT" {
					OT_LogWrite 3 "Tote feed timed out"
					set ret_list [list REJECT  TOTE_TIMEOUT]
				}
				default {
					OT_LogWrite 3 "Tote feed returned an invalid return code: [lindex $ret_list 0]"
					set ret_list [list REJECT  TOTE_DEFAULT]
				}
			}

		} err]} {
			OT_LogWrite 3 "error while handling Tote feed response: $err"
			set ret_list [list REJECT  TOTE_FAILED_CONNECT]
		}

		close $sock

		return $ret_list
	}

	proc mjc_complete {pending_id} {

		variable pool_info
		variable bet_info

		# Heavy error shit going down here to make sure we close sockets
		# etc. Don't want 'em lying about all over the place.
		set ret PENDING


		# Connect to ORBIS_MJC_SERVER

		if {[OB_mjc_connect::connect "[OT_CfgGet ORBIS_BETAPP_HOST]" "[OT_CfgGet ORBIS_BETAPP_PORT]"] != 1} {
			log 3 "mjc_complete: unable to connect to server: $OB_mjc_connect::err_msg"
			return REJECT
		}

		log 3 "*Connected*"


		# Send the bet
		if {[catch {
			set ret [OB_mjc_connect::snd_msg "$pool_info(bet_msg)"]
		} err]} {
			log 3 "mjc_complete: error sending bet: $err"
			catch {OB_mjc_connect::disconnect} err
			return PENDING
		}

		# Store any errors
		set bet_info(pool_error) $OB_mjc_connect::err_msg


		# Disconnect
		if {[catch {
			OB_mjc_connect::disconnect
		} err]} {
			# If got this far assume bet placed but warn
			log 3 "mjc_complete: error disconnecting: $err"
		}

		log 20 "Return: $ret Error: $bet_info(pool_error)"


		# Return OK/TIMEOUT/PENDING/REJECT
		# !! For testing, can just uncomment this lineX
		#set ret "OK"

		return $ret
	}


	#
	# Maps pool-provider codes or messages to whatever we want.
	# message_map should be defined in the customer code with an array set.
	# For Tote, it's used to map Tote's bet error codes to customer-specific
	# ml codes which are stored in tPoolBet.settle_info so they can be
	# displayed on the customer's receipt.
	#
	proc map_msg { msg } {
		variable message_map

		ob::log::write DEV "==>[info level [info level]]"

		if { $msg == "" } {
			return ""
		}

		if { [info exists message_map($msg)] } {
			return $message_map($msg)
		}

		if { [info exists message_map(DEFAULT)] } {
			return $message_map(DEFAULT)
		}

		return DEFAULT
	}

	# Ask the Authentication Server whether this customer can place the
	# bet in the given area based on their region cookie.
	#
	# auth_type - the type of authentication required
	#             (bet)
	#
	# returns - OK if authenticated, a multi-lingual message code otherwise
	#
	proc authenticate_pools {action_source {auth_type "bet"} {channel ""} {application "default"}} {

		set add_item ""

		# Set the name of the additional item
		switch -exact -- $action_source {
			"T" {
				set add_item "TRNI"
			}
			"U" {
				set add_item "Tote"
			}
			default {
				pool_error MINOR UNKNOWN_SOURCE "unknown pool source: $action_source"
			}
		}

		set region_cookie [OB::AUTHENTICATE::retrieve_region_cookie]
		set cust_id [ob_login::get cust_id]

		set ip      [reqGetEnv REMOTE_ADDR]

		if {$channel == ""} {
			set channel [reqGetArg channel]
		}

		set allow_tran [OB::AUTHENTICATE::authenticate $application $channel $cust_id \
			$auth_type 0 $ip $region_cookie "" "" "" "" "Y" "" "" $add_item]


		OB::AUTHENTICATE::store_region_cookie [lindex $allow_tran 2]

		if {[lindex $allow_tran 0] != "S"} {
			if {[string trim [lindex [lindex $allow_tran 1] 0]] == "COUNTRY_ADD_ALLOWED" || \
				[string trim [lindex [lindex $allow_tran 1] 0]] == "COUNTRY_CHAN_ALLOWED" } {
				return "BANNED_ITEM"
			}
			return [lindex [lindex $allow_tran 1] 2]
		}
		return OK
	}

	proc get_pool_info {} {
		variable pool_info
		return [array get pool_info]
	}

	proc get_bet_info {} {
		variable bet_info
		return [array get bet_info]
	}
}
