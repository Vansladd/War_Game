# ============================================================================
# $Id: stl-pool.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2002 Orbis Technology Ltd. All rights reserved.
# ============================================================================

# Pools Settler

namespace eval ADMIN::SETTLE::POOLS {

proc slog {level msg} {

	OT_LogWrite $level $msg

	if {[llength [info commands tpBufWrite]]} {
		tpBufWrite $msg
		tpBufWrite "\n"
		tpBufFlush
	}
}

proc log {level msg} {
	OT_LogWrite $level $msg
}

proc stl_settle_all_pools {} {
	set stmt [stl_qry_prepare GET_UNSETTLED_POOLS]
	if [catch {set res [inf_exec_stmt $stmt]} err] {
		slog 1 "Error getting all pools"
		return NO
	}

	set nrows [db_get_nrows $res]

	for {set row 0} {$row < $nrows} {incr row} {
		if {[catch {set settled [stl_settle_pool [db_get_col $res $row pool_id]]} err]} {
			log 3 "error settling pool [db_get_col $res $row pool_id]: $err"
			return NO
		} elseif {$settled == "NO"} {
			set ret "NO"
		}
	}

	return YES
}

proc stl_settle_evt_pools {ev_id} {

	set stmt [stl_qry_prepare GET_POOLS_FOR_EVENT]

	if [catch {set res [inf_exec_stmt $stmt $ev_id]} err] {
		slog 1 "Error getting pools for event $ev_id"
		return NO
	}

	set nrows [db_get_nrows $res]

	for {set row 0} {$row < $nrows} {incr row} {
		if {[catch {set settled [stl_settle_pool [db_get_col $res $row pool_id]]} err]} {
			log 3 "error settling pool [db_get_col $res $row pool_id]: $err"
			return NO
		} elseif {$settled == "NO"} {
			set ret "NO"
		}
	}

	return YES
}


proc stl_settle_mkt_pools {mkt_id} {

	global DB

	set stmt [stl_qry_prepare GET_POOLS_FOR_MARKET]

	slog 3 "settling market pools"

	if [catch {set res [inf_exec_stmt $stmt $mkt_id]} err] {
		slog 1 "Error getting pools for market $mkt_id"
		return NO
	}

	set nrows [db_get_nrows $res]
	set ret YES

	for {set row 0} {$row < $nrows} {incr row} {
		if {[catch {set settled [stl_settle_pool [db_get_col $res $row pool_id]]} err]} {
			log 3 "error settling pool [db_get_col $res $row pool_id]: $err"
			set ret NO
		} elseif {$settled == "NO"} {
			set ret "NO"
		}
	}

	return $ret
}


#
# ----------------------------------------------------------------------------
# Settle the indicated pool
#
# One of two status values is returned:
#   NO      - the pool cannot be settled
#   SETTLED - the pool has been settled
#
# If an error occurs (there are lots of things that can go wrong), it
# needs to be causght by the caller
# ----------------------------------------------------------------------------
#
proc stl_settle_pool {pool_id {clobber 1}} {
	global USERNAME errorInfo

	variable POOL
	variable SELN
	variable FAV
	variable BET

	slog 1 "Attempting to settle pool #$pool_id"

	if {$clobber != 0} {
		catch {unset POOL}
		catch {unset SELN}
		catch {unset FAV}
	}

	set status "NO"

	set err_num 0

	# Loops through each of the bets returned by
	# stl_get_bets and settles them
	foreach bet_id [stl_get_bets $pool_id] {
		if {[catch {
			if {[stl_settle_bet_pool $bet_id] != "SETTLED"} {
				incr err_num
			}
		} err]} {
			log 5 $errorInfo
			incr err_num
		}
	}

	if {$err_num == 0} {
		slog 1 "Settlement for pool #$pool_id returning SETTLED"
		set stmt [stl_qry_prepare SETTLE_POOL]
		set status "SETTLED"

		if [catch {inf_exec_stmt $stmt $USERNAME $pool_id} msg] {
			slog 1 "failed to mark pool #$pool_id as settled"
			error "failed to mark pool #$pool_id as settled"
		}
	} else {
		slog 1 "Settlement for pool #$pool_id returning NO"
		slog 1 "$err_num bets not settled"
		set status "NO"
	}

catch {unset BET}

return $status
}

# This little beauty calculates combinations and
# permutations based on rules from the database.
# If the bet type is unordered it returns ascending
# sorted lists of perms (as does the dividend functions
# so that quick comparisons can be made to test for
# winners etc.
proc calc_perms {bet_id} {
	variable POOL
	variable BET

	foreach pool_id $BET($bet_id,pools) {
		# Setup the right function
		set no_perm 0

		log 30 "calc_perms: calculating perms for '$POOL($pool_id,leg_type)' leg type"
		log 30 "floating_bankers = $BET($bet_id,$pool_id,floating_bankers)"

		switch -- $POOL($pool_id,leg_type) {
			O {
				if {$BET($bet_id,$pool_id,floating_bankers) == 1} {
					set pfunc ot::genCombis
				} else {
					set pfunc ot::genPerms
				}
			}
			U {
				set pfunc ot::genCombis
			}
			W -
			P {
				set pfunc {}
				set no_perm 1
				for {set leg 1} {$leg <= $POOL($pool_id,num_legs)} {incr leg} {
					set pk "$bet_id,$pool_id,$leg"
					set BET($pk,perms) $BET($pk,places)
					set BET($pk,num_lines) [llength $BET($pk,perms)]
				}
			}
		}

		# Go through each leg
		for {set leg 1} {$leg <= $POOL($pool_id,num_legs)} {incr leg} {
			set pk "$bet_id,$pool_id,$leg"

			# If this leg's void then don't mess
			#if {$POOL($pool_id,$leg,leg_void) == "Y"} {
			#	set BET($pk,perms) {}
			#	set BET($pk,num_lines) 0
			#	continue
			#}

			set nbankers $BET($pk,banker_places)
			set num_picks $POOL($pool_id,num_picks)
			log 50 "num_picks($pool_id) = $num_picks"
			log 50 "num_bankers = $nbankers"

			if {$BET($pk,places) == {}} {
				set places {}
			} else {
				if {$no_perm} {
					set places $BET($pk,places)
				} else {
					set places [$pfunc [expr {$num_picks - $nbankers}] $BET($pk,places)]
				}
			}

			set newperms {}
			if {$BET($pk,banker_places) > 0} {
				if {$BET($pk,banker_places) > 1} {
					# Work out all the banker permutations first
					set perms $BET($pk,bankers,1)

					# Loop through each of the bankers
					for {set place 2} {$place <= $nbankers} {incr place} {
						set newperms {}

						foreach perm $perms {
							foreach banker $BET($pk,bankers,$place) {
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
					if {$POOL($pool_id,leg_type) == "U" && $BET($pk,banker_places) > 1} {
						set newperms {}

						foreach perm $perms {
							set revvoidmap {}
							# This sorts the perms even if they've got V's appended to them
							# The V's get put back on after the perm's been sorted.
							if {[string first "V" $perm] != -1} {
								set voidmap [regexp -all -inline {([0-9][0-9]*)V} $perm]
								foreach {a b} $voidmap {
									lappend revvoidmap $b $a
								}
								log 50 "converting $perm to [string map $voidmap $perm]"
								set perm [string map $voidmap $perm]
							}

							set nperm [lsort -integer -increasing $perm]
							log 50 "converting $nperm back to [string map $revvoidmap $nperm]"
							set nperm [string map $revvoidmap $nperm]

							if {[lsearch -exact $newperms $nperm] == -1} {
								lappend newperms $nperm
							}
						}
						set perms $newperms
					}
				} else {
					set perms [$pfunc $nbankers $BET($pk,bankers,1)]
				}

				# Then, if there are any places, we add them now
				if {$places != {}} {
					set newperms {}
					foreach perm $perms {
						foreach place $places {
							if {[lsearch $perm $place] == -1} {
								set tmpperm [concat $perm $place]
								lappend newperms $tmpperm
							}
						}
					}
					set perms $newperms
				}

				# If we're a floater then we need to mix these little puppies up
				if {$BET($bet_id,$pool_id,floating_bankers) == 1} {
					set newperms {}
					foreach perm $perms {
						set newperms [concat $newperms [ot::genPerms $num_picks $perm]]
					}
					set perms $newperms
				}
				set BET($pk,perms) $perms
			} else {
				set BET($pk,perms) $places
			}
			set BET($pk,num_lines) [llength $BET($pk,perms)]
			log 90 "calc_perms: $pk: $BET($pk,perms)"
		}
	}
}

#
# --------------------------------------------------------------------------
# Settles the given bet
# --------------------------------------------------------------------------
#
proc stl_settle_bet_pool {bet_id} {
	variable POOL
	variable BET
	variable SELN
	variable FAV

	#catch {unset POOL}

	slog 5 "settling bet \#$bet_id"

	# Get the information about this pool that'll let
	# me reproduce the lines I require.
	# Also, this function gets all the nonsense about
	# tPoolDividend.

	if {![info exists BET($bet_id,pools)]} {
		if {[stl_get_bets $bet_id bet] == {}} {
			log 3 "Cannot retrieve bet information"
			return "NO"
		}
	}

	if {$BET($bet_id,result_conf) == "N"} {
		log 3 "Results not confirmed"
		return "NO"
	}

	set num_pools 0

	log 20 "   bet used pools: $BET($bet_id,pools)"

	set all_void "Y"

	foreach pool_id $BET($bet_id,pools) {
		incr num_pools
		set pool_num($num_pools) $pool_id

		if {![info exists POOL(pools)] || [lsearch $POOL(pools) $pool_id] == -1} {
			stl_get_pool_info $pool_id
		}

		if {$all_void == "Y" && $POOL($pool_id,pool_void) == "N"} {
			set all_void "N"
		}

		if {$POOL($pool_id,result_conf) != "Y"} {
			slog 5 "   cannot settle this bet, not all markets have results: $pool_id"
			return "NO"
		}
		set BET($bet_id,$pool_id,floating_bankers) 0
	}

	if {$all_void == "Y"} {
		slog 5 "   all legs are scratched, settling as scratched"
		if {[OT_CfgGet TEST_SETTLE 0] == 0} {
			settle_pool_bet $bet_id 0 0 $BET($bet_id,num_lines) 0 $BET($bet_id,stake)
		}
		return SETTLED

	}

	log 10 "   bet consists of [llength $BET($bet_id,pools)] pools: [join $BET($bet_id,pools) ", "]"

	# Go through each pool for this bet
	foreach pool_id $BET($bet_id,pools) {
		# Make sure all our selections have results

		log 10 "   pool $pool_id has $POOL($pool_id,num_legs) legs"

		for {set leg 1} {$leg <= $POOL($pool_id,num_legs)} {incr leg} {

			set pk "$bet_id,$pool_id,$leg"


			set BET($pk,places) {}
			set BET($pk,banker_places) 0
			set BET($pk,has_voids) 0

			for {set part 1} {$part <= $BET($pk,num_parts)} {incr part} {

				if {$BET($pk,$part,result) == "-" && $POOL($pool_id,$leg,leg_void) == "N" && $POOL($pool_id,pool_void) == "N"} {
					# If there's no result and neither the leg or the pool is void then this is not good!
					log 5 "   no result for selection $BET($pk,$part,ev_oc_id) in pool $pool_id"
					return "NO"
				} elseif {$BET($pk,$part,result) == "V" || $POOL($pool_id,$leg,leg_void) == "Y" || $POOL($pool_id,pool_void) == "Y"} {
					# If this result's void then we append it with a "V" to mark
					# it void. This gets handled later
					append BET($pk,$part,ev_oc_id) "V"
					set BET($pk,has_voids) 1
				} elseif {[regexp {^[12]$} $BET($pk,$part,fb_result) fav_pos]} {
					# it's the Nth unnamed favourite - substitute for Nth named favourite
					#
					set ev_mkt_id $BET($pk,$part,ev_mkt_id)
					log 50 "unnamed favourite $BET($pk,$part,ev_oc_id) replace with favourite [lindex $FAV($ev_mkt_id) [expr {$fav_pos - 1}]]"
					set BET($pk,$part,ev_oc_id) [lindex $FAV($ev_mkt_id) [expr {$fav_pos - 1}]]
				}

				# Handle bankers
				if {$BET($pk,$part,banker_info) == ""} {
					lappend BET($pk,places) $BET($pk,$part,ev_oc_id)
				} else {
					# This is a banker
					if {![regexp {B(M?)([0-9]+)} $BET($pk,$part,banker_info) all floating place]} {
						log 1 "stl_settle_bet_pool: badly formatted banker_info: $BET($pk,$part,banker_info)"
						return NO
					}

					lappend BET($pk,bankers,$place) $BET($pk,$part,ev_oc_id)

					if {$place > $BET($pk,banker_places)} {
						set BET($pk,banker_places) $place
					}

					if {$floating == "M"} {
						set BET($bet_id,$pool_id,floating_bankers) 1
					}
				}
			}
		}
		log 50 "pool_id($pool_id) floating_bankers = $BET($bet_id,$pool_id,floating_bankers)"
	}

	# Calculates the permutations for each of the legs
	calc_perms $bet_id
	set total_perms 0

	catch {unset bet}

	# Check for voids
	foreach pool_id $BET($bet_id,pools) {
		for {set leg 1} {$leg <= $POOL($pool_id,num_legs)} {incr leg}  {
			set pk "$bet_id,$pool_id,$leg"

			log 90 "BET($pk,perms) = $BET($pk,perms)"

			# If we've got some voids in our perms then we need
			# to substitute them. void_action must be S for us to
			# do this though
			#if {$POOL($pool_id,$leg,leg_void) == "Y"} {
			#	set bet($pool_id,$leg) {}
			#} else
			if {$BET($pk,has_voids)} {
				foreach perm $BET($pk,perms) {
					if {[string first "V" $perm] == -1} {
						# No voids in this particular perm
						log 50 "$perm is fine, no voids here"
						set newperm $perm
					} elseif {$POOL($pool_id,void_action) != "S" || $POOL($pool_id,pool_void) == "Y" || $POOL($pool_id,$leg,leg_void) == "Y"} {
						# Hmmm... we're doing refunds not substitutes
						log 50 "$perm is void, refunding"
						set newperm "V"
					} else {
						# Righto, lets look for the bloody substitutes

						# Just so this is clear...
						# subs contains our list of substitutes in
						# favourite order
						set subs $FAV($POOL($pool_id,$leg,ev_mkt_id))
						# If we've got more substitutes than we're
						# allowed then chop the list down to just the
						# number required
						if {[llength $subs] > $POOL($pool_id,num_subs)} {
							set subs [lrange $subs 0 [expr {$POOL($pool_id,num_subs) - 1}]]
						}

						set newbet {}
						set newperm $perm

						log 50 "$perm is not fine, find some substitutes"

						catch {unset varr}
						array set varr [regexp -all -inline -- {([0-9]+)V} $BET($pk,perms)]

						while {[set idx [lsearch -glob $newperm "*V"]] != -1} {
							log 50 "subs available $subs, #subs allowed to use $POOL($pool_id,num_subs), newperm = $newperm"
							if {$subs == {}} {
								# Doh, run out of substitutes so this perm's void
								set newperm "V"
								log 50 "break 1"
								break
							}
							set seln [string trimright [lindex $newperm $idx] "V"]
							set ev_mkt_id $SELN($seln,ev_mkt_id)
							set vid [lindex $newperm $idx]

							while {$subs != {}} {
								# Get the next substitute from the list
								set sub [lindex $subs 0]
								# and remove it from our list
								set subs [lrange $subs 1 end]

								if {[lsearch $newperm $sub] == -1} {
									# If our new substitute isn't in the bet already then use it
									set newperm [lreplace $newperm $idx $idx $sub]
									log 20 "   substituting $sub in place of $seln"
									log 50 "break 2"
									break
								}
							}

							if {[lsearch $newperm "V"] != -1} {
								# We must have run out of subs - this shouldn't really happen
								set newperm "V"
								log 50 "break 4"
								break
							}
						}
					}

					log 50 "newperm = $newperm"

					set perm {}
					foreach p $newperm {
						set np {}
						foreach s $p {
							if {$s != "V"} {
								lappend np $SELN($s,runner_num)
								# rev_map is a reverse mapping of pool, leg and runner number
								# back to ev_oc_id
								#set rev_map($pool_id,$leg,$SELN($s,runner_num)) $s
							} else {
								lappend np "V"
							}
						}
						lappend perm $np
					}
					if {$POOL($pool_id,leg_type) == "U"} {
						set perm [lsort -integer -increasing $perm]
					}

					log 50 "adding substituted perms $perm"
					lappend bet($pool_id,$leg) $perm
				}
			} else {
				# No voids, just go ahead
				set perm {}
				foreach p $BET($pk,perms) {
					set np {}
					foreach s $p {
						lappend np $SELN($s,runner_num)
						#set rev_map($pool_id,$leg,$SELN($s,runner_num)) $s
					}
					if {$POOL($pool_id,leg_type) == "U"} {
						lappend perm [lsort -integer -increasing $np]
					} else {
						lappend perm $np
					}
				}

				set bet($pool_id,$leg) $perm
			}
		}

		for {set lno 1} {$lno <= $POOL($pool_id,num_legs)} {incr lno} {
			log 90 "      leg($lno) = $bet($pool_id,$lno)"
		}
	}




	# div_winners holds each leg as a list
	# e.g. the following refund dividend might look like
	# div_winners(-1) {1 4} {2} {}
	# where the 1st and 4th perms in the 1st leg, 2nd perm in
	# the 2nd leg and no perms in the 3rd leg happen to be voids
	# and in this case therefore refunds.
	# winning_divs just keep track of the dividends that have
	# got returns

	set pool_no 0
	catch {unset pool_returns}
	catch {unset non_void}
	foreach pool_id $BET($bet_id,pools) {
		incr pool_no
		log 90 "checking pool $pool_no"

		set pool_returns($pool_no) {}
		set winning_divs {}
		set POOL($pool_id,div,-1,consolation) 0
		set POOL($pool_id,div,-1,dividend) -1.0

		# initialise all div_winners entries and add all dividends to
		# winning_divs
		for {set div 0} {$div < $POOL($pool_id,div,num_divs)} {incr div} {
			set div_winners($div) {}
			lappend winning_divs $div
		}

		set non_void($pool_no) 1

		for {set leg 1} {$leg <= $POOL($pool_id,num_legs)} {incr leg} {
			set new_winning_divs {}

			set perms $bet($pool_id,$leg)
			set nperms [llength $perms]
			set permlist {}

			log 50 "pool($pool_no),leg($leg): $perms"

			# This loop creates a list of indexes of each perm in the
			# list i.e. the first perm in a list would be 0
			if {$BET($bet_id,$pool_id,$leg,has_voids) == 1} {
				set voids {}
				for {set perm 0} {$perm < $nperms} {incr perm} {
					if {[lindex $perms $perm] == "V"} {
						lappend voids $perm
					} else {
						lappend permlist $perm
					}
				}
			} else {
				for {set perm 0} {$perm < $nperms} {incr perm} {
					lappend permlist $perm
				}
			}

			# Need to know the number of non_void runners so we can
			# work out how many voids we've got!
			set non_void($pool_no) [expr {$non_void($pool_no) * [llength $permlist]}]

			foreach div $winning_divs {
				set dividend $POOL($pool_id,div,$div,leg_$leg)
				set winners {}

				if {$dividend == "*"} {
					lappend new_winning_divs $div
					foreach perm $permlist {
						lappend winners $perm
					}
				} else {
					foreach perm $permlist {
						set ok 0
						log 50 "checking perm([lindex $perms $perm]) for void"
						if {[lindex $perms $perm] == "V"} {
							set ok 1
						} elseif {$POOL($pool_id,grouped_divs) == "Y"} {
							foreach subdiv $dividend {
								if {[ot::lsub [lindex $perms $perm] $subdiv] == 1} {
									set ok 1
									break
								}
							}
						} elseif {[ot::lsub [lindex $perms $perm] $dividend] == 1} {
							set ok 1
						}

						if {$ok} {
							if {[lsearch $new_winning_divs $div] == -1} {
								lappend new_winning_divs $div
							}
							log 50 "adding perm\# $perm to winners for div $div"
							lappend winners $perm
						}
					}
				}

				if {$winners != {}} {
					lappend div_winners($div) $winners
				}
			}

			set winning_divs $new_winning_divs
		}

		set normals {}
		set normal_divs {}
		set consolations {}
		set consolation_divs {}

		# expand out winning perms
		log 50 "winning_divs: $winning_divs"
		foreach div $winning_divs {
			log 90 "expanding dividend $div"
			log 90 "div_winners($div): $div_winners($div)"
			set winningdivs($div) [lindex $div_winners($div) 0]

			for {set leg 1} {$leg < $POOL($pool_id,num_legs)} {incr leg} {
				set newwinningdivs {}
				foreach perm [lindex $div_winners($div) $leg] {
					foreach wdiv $winningdivs($div) {
						lappend newwinningdivs [concat $wdiv $perm]
					}
				}
				set winningdivs($div) $newwinningdivs
			}

			log 90 "winningdivs($div) = $winningdivs($div)"

			if {$POOL($pool_id,div,$div,consolation)} {
				lappend consolation_divs $div
				set consolations [concat $consolations $winningdivs($div)]
			} else {
				lappend normal_divs $div
				set normals [concat $normals $winningdivs($div)]
			}
		}

		log 90 "normal_divs: $normal_divs"
		log 90 "normals: $normals"
		log 90 "consolation_divs: $consolation_divs"
		log 90 "consolations: $consolations"

		# Goes through all the non consolations and adds them up
		foreach div $normal_divs {
			foreach subdiv $winningdivs($div) {
				lappend pool_returns($pool_no) $POOL($pool_id,div,$div,dividend)
			}
		}

		# Goes through each of the consolations
		foreach div $consolation_divs {
			set payout 0.0

			foreach subperm $winningdivs($div) {
				# Check to see that we've not covered this with a winning dividend
				if {[lsearch $normals $subperm] == -1} {
					log 50 "consolation $subperm not found in normals"
					lappend pool_returns($pool_no) $POOL($pool_id,div,$div,dividend)
				}
			}
		}

		log 90 "returns($pool_no): $pool_returns($pool_no)"
	}


	set leg_maps [BETPERM::bet_lines $BET($bet_id,bet_type)]
	# Stake Per Line
	set spl [expr {$BET($bet_id,stake) / $BET($bet_id,num_lines)}]

	set refunds 0.0
	set payouts 0.0
	set num_refunds 0
	set num_payouts 0
	set nvoid 0

	log 50 "workings: $BET($bet_id,bet_type) $BET($bet_id,desc)"
	log 50 "workings: stake per line = \$$spl"
	log 50 "leg_maps: $leg_maps"
	foreach leg_map $leg_maps {
		set lm_len [llength $leg_map]

		log 50 "workings: leg [join $leg_map " x "]"

		set line_payout 0.0

		if {$lm_len == 1} {
			set leg $leg_map
			log 1 "pool_returns($leg) = $pool_returns($leg)"
			foreach div $pool_returns($leg) {
				set line_payout [expr {$line_payout + (round($spl * $div * 100.0) / 100.0)}]
				incr num_payouts
				log 50 "workings: + ($spl * $div) = [expr {$spl * $div}] = [expr {round($spl * $div * 100.0) / 100.0}] ~ winnings"
			}
			incr nvoid $non_void($leg)
		} else {
			set vals {1.0}
			set count 0
			set nv 1
			log 1 "pool_returns($leg) = $pool_returns($leg)"

			foreach leg $leg_map {
				incr count
				set new_vals {}
				foreach val $vals {
					foreach div $pool_returns($leg) {
						lappend new_vals [expr {$val * $div}]
					}
				}
				set vals $new_vals
				set nv [expr {$nv * $non_void($leg)}]
			}

			log 50 "$vals"

			foreach val $vals {
				incr num_payouts
				set payout [expr {round($val * $spl * 100.0) / 100.0}]
				log 50 "workings: + ($val * \$$spl) = [expr {$val * $spl}] = $payout ~ winnings"
				log 5 "payout: $payout"
				set line_payout [expr {$line_payout + $payout}]
			}
			incr nvoid $nv
		}

		log 50 "nvoid: $nvoid"
		log 50 "line_payout: $line_payout"

		# round down to 1 decimal place
		# I was using floor (and tried int) but it was rounding
		# incorrectly. What appeared to be 507.0 was changing to
		# 506.9 when using floor. Format has no such worries.
		# Update: after testing (really)... I find that format does
		# have worries as it rounds up/down rather than truncates
		# So, I've had to resort to this absolute cack in order to
		# round down!!! Madness.
		log 50 "payouts before rounding down: $payouts"
		# set payouts [format "%0.1f" $payouts]
		set payouts [expr {$line_payout + ([lindex [split [expr {$payouts * 10.0}] "."] 0] / 10.0)}]
		log 50 "payouts after rounding down: $payouts"
	}

	set num_lose [expr {$nvoid - $num_payouts}]
	set num_refunds [expr {$BET($bet_id,num_lines) - $num_lose - $num_payouts}]
	set refunds [expr {floor(($num_refunds * $spl * 100.0) + 0.005) / 100.0}]

	log 50 "workings: winnings = $payouts"
	log 50 "workings: refunds = $refunds"
	log 50 "workings: winnings + refunds = [expr {$payouts + $refunds}]"
	log 50 "workings:"

	foreach val {num_refunds refunds num_payouts payouts} {
		log 90 "$val: [subst $$val]"
	}

	set num_lose [expr {$BET($bet_id,num_lines) - $num_refunds - $num_payouts}]
	if {[tpGetVar StlLosers] != 1} {
		slog 50 "desc: $BET($bet_id,desc) - \$$spl"
		slog 50 "num_refunds: $num_refunds"
		slog 50 "num_payouts: $num_payouts"
		slog 50 "num_lose: $num_lose"
		slog 50 "num_lines: $BET($bet_id,num_lines)"
		slog 50 "refunds: $refunds"
		slog 50 "payouts: $payouts"
		slog 50 "total: [expr {$refunds + $payouts}]"
		slog 50 "reconcile: $bet_id,$BET($bet_id,num_lines),$num_payouts,$num_refunds,$num_lose,$payouts,$refunds"
	} elseif {[OT_CfgGetTrue PP_HACK]} {
		slog 1 "Winning bet: Receipt: $BET($bet_id,receipt)"
		slog 1 "      Stake Per Line: $spl"
		slog 1 "           Lines won: $num_payouts"
		slog 1 "      Lines refunded: $num_refunds"
		return NO
	}

	slog 50 ""

	if {$num_lose == $BET($bet_id,num_lines)} {
		# stl_bet_lose $bet_id
		if {[OT_CfgGet TEST_SETTLE 0] == 0} {
			settle_pool_bet $bet_id 0 $BET($bet_id,num_lines) 0 0 0
		}
		return SETTLED
	}

	if {[OT_CfgGet TEST_SETTLE 0] == 0 && [tpGetVar StlLosers] != 1} {
		settle_pool_bet $bet_id $num_payouts $num_lose $num_refunds $payouts $refunds
	}

	return SETTLED
}

# This is a copy of stl_settle_bet_do_db but redesigned to make use of the
# new BET array. This is a temporary measure until I've rewritten the
# stl_settle_bet_do_db and may also depend on the changes that Chris
# has made in his part of the settlement.
proc settle_pool_bet {bet_id nw nl nv winnings refund} {

	global USERNAME errorInfo
	variable BET
	variable ::ADMIN::SETTLE::PARK_ON_WINNINGS_ONLY
	variable ::ADMIN::SETTLE::CHANNELS_TO_ENABLE_PARKING
	set stmt [stl_qry_prepare BET_WIN_REFUND]

	# if the bet from a channel with parking enabled, make sure
	# that the correct parking enabled value is send to the query
	if {[lsearch -exact $CHANNELS_TO_ENABLE_PARKING $BET($bet_id,source)]!=-1} {
		set enable_parking "Y"
	} else {
		set enable_parking "N"
	}

	# if this option is enabled the bet park limit is applied
	# to the winnings rather than the winnings + refund
	if {$PARK_ON_WINNINGS_ONLY} {
		set park_limit_on_winnings "Y"
	} else {
		set park_limit_on_winnings "N"
	}

	inf_exec_stmt $stmt\
		$USERNAME\
		$bet_id\
		$nw\
		$nl\
		$nv\
		$winnings\
		$refund\
		""\
		$enable_parking\
		$park_limit_on_winnings
	return
}

#
# ----------------------------------------------------------------------------
# Prepare a query - return a cached statement id if we have one
# ----------------------------------------------------------------------------
#
proc stl_qry_prepare qry {

	global DB

	variable STL_QRY

	if [info exists STL_QRY($qry,stmt)] {
		incr STL_QRY($qry,use_count)
		return $STL_QRY($qry,stmt)
	}
	set stmt [inf_prep_sql $DB $STL_QRY($qry,sql)]

	set STL_QRY($qry,stmt)      $stmt
	set STL_QRY($qry,prep_time) [clock seconds]
	set STL_QRY($qry,use_count) 1

	return $stmt
}

#
# ----------------------------------------------------------------------------
# Gets bet information for each of the bets for the given pool
# ----------------------------------------------------------------------------
#
proc stl_get_bets {id {type pool}} {
	variable BET
	variable SELN
	variable STL_QRY
	global DB

	set bet_ids {}

	log 50 "   getting pool bet ids"

	switch $type {
		pool {
			set stmt [stl_qry_prepare GET_POOL_BET_IDS]
			inf_exec_stmt $stmt $id
		}
		bet {
			set stmt [stl_qry_prepare DROP_TEMPORARY]
			inf_exec_stmt $stmt
			set stmt [stl_qry_prepare GET_POOL_BET_IDS_FOR_BET]
			inf_exec_stmt $stmt $id
			log 5 "getting details for pool_bet_id $id"
		}
		default {
			error "stl_get_pool_bets: unknown type: $type"
		}
	}

	log 50 "   retrieving main bets"
	set stmt [inf_prep_sql $DB $STL_QRY(GET_POOL_BETS,sql)]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt
	set nrows [db_get_nrows $res]

	# Get the bet information (not the selections)
	for {set row 0} {$row < $nrows} {incr row} {
		set bet_id [db_get_col $res $row pool_bet_id]
		lappend bet_ids $bet_id

		# Get the information about the bet (not the individual selections)
		if {![info exists BET($bet_id,bet_id)]} {
			foreach col [db_get_colnames $res] val [db_get_row $res $row] {
				set BET($bet_id,$col) $val
			}
		}
	}

	db_close $res

	log 50 "   retrieving bet details, $nrows bets"

	set stmt [inf_prep_sql $DB $STL_QRY(GET_POOL_BET_DETAILS,sql)]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt
	set nrows [db_get_nrows $res]

	set last_bet -1

	# Get the selection details for our bets
	for {set row 0} {$row < $nrows} {incr row} {
		set bet_id [db_get_col $res $row pool_bet_id]
		set pool_id [db_get_col $res $row pool_id]
		set leg_no [db_get_col $res $row leg_no]
		set part_no [db_get_col $res $row part_no]
		set result_conf [db_get_col $res $row result_conf]

		if {![info exists BET($bet_id,pools)]} {
			set BET($bet_id,pools) $pool_id
			set BET($bet_id,bet_ccy) [db_get_col $res $row bet_ccy]
			set BET($bet_id,result_conf) $result_conf
		} elseif {[lsearch $BET($bet_id,pools) $pool_id] == -1} {
			lappend BET($bet_id,pools) $pool_id
		}

		if {$BET($bet_id,result_conf) == "Y" && $result_conf == "N"} {
			set BET($bet_id,result_conf "N"
		}

		if {$last_bet != $bet_id} {
			set last_bet $bet_id
			set last_pool -1
		}

		if {$last_pool != $pool_id} {
			set last_pool $pool_id
			set last_leg -1
			set real_leg 0
		}

		if {$last_leg != $leg_no} {
			set last_leg $leg_no
			incr real_leg
			set part_no 1
			set BET($bet_id,$pool_id,$real_leg,num_parts) 1
		} else {
			incr BET($bet_id,$pool_id,$real_leg,num_parts)
		}

		set pk "$bet_id,$pool_id,$real_leg,$part_no"

		foreach col [db_get_colnames $res] val [db_get_row $res $row] {
			if {$col != $leg_no && $col != $part_no} {
				set BET($pk,$col) $val
			}
		}
	}

	db_close $res

	return $bet_ids
}

#
# ----------------------------------------------------------------------------
# Function used to order the runners in a race in order of odds
# If the odds are the same (joint favourites) then the lowest runner
# number comes first. Blank odds are always sorted last.
# ----------------------------------------------------------------------------
#
proc compare_odds {a b} {
	set a_odds [lindex $a 2]
	set a_num [lindex $a 1]
	set b_odds [lindex $b 2]
	set b_num [lindex $b 1]

	if {$a_odds != "" && $b_odds == ""} { return -1 }
	if {$a_odds == "" && $b_odds != ""} { return 1 }
	if {$a_odds != "" && $b_odds != ""} {
		if {$a_odds < $b_odds} { return -1 }
		if {$a_odds > $b_odds} { return 1 }
	}
	if {$a_num < $b_num} { return -1 }
	if {$a_num > $b_num} { return 1 }
	return 0
}

#
# ----------------------------------------------------------------------------
# Get pools and pools dividend information
# ----------------------------------------------------------------------------
#
proc stl_get_pool_info {pool_id} {
	variable POOL
	variable FAV
	variable SELN

	# If we've got the details for this pool then return
	if {[info exists POOL(pools)] && [lsearch $POOL(pools) $pool_id] != -1} {
		return 1
	}

	# Get the information about the pool
	set stmt [stl_qry_prepare GET_POOL_INFO]
	set res [inf_exec_stmt $stmt $pool_id]

	set nrows [db_get_nrows $res]
	log 10 "stl_get_pool_info: got $nrows pool row(s), pool_id = $pool_id"

	if {$nrows > 0} {
		foreach col {num_legs leg_type void_action bet_type num_subs pool_settled status pool_void min_runners num_picks grouped_divs} {
			set POOL($pool_id,$col) [db_get_col $res 0 $col]
		}
	}

	set POOL($pool_id,result_conf) "Y"
	set POOL($pool_id,mkts) [list]

	for {set idx 0} {$idx < $nrows} {incr idx} {
		lappend POOL($pool_id,mkts) [db_get_col $res $idx ev_mkt_id]
		set POOL($pool_id,[db_get_col $res $idx leg_num],ev_mkt_id) [db_get_col $res $idx ev_mkt_id]
		set POOL($pool_id,[db_get_col $res $idx leg_num],leg_void) [db_get_col $res $idx leg_void]

		if {[db_get_col $res $idx result_conf] == "N"} {
			set POOL($pool_id,result_conf) "N"
		}
	}

	db_close $res

	foreach ev_mkt_id $POOL($pool_id,mkts) {

		# Get the runner_nums and ev_oc_ids for everything in the market
		set SELN(ev_oc_id) [list]
		set stmt [stl_qry_prepare GET_RUNNER_NUMS_BY_MKT]
		set res [inf_exec_stmt $stmt $ev_mkt_id]
		for {set idx 0} {$idx < [db_get_nrows $res]} {incr idx} {
			lappend SELN(ev_oc_id) [db_get_col $res $idx ev_oc_id]
			set SELN([db_get_col $res $idx ev_oc_id],runner_num) [db_get_col $res $idx runner_num]
			set SELN([db_get_col $res $idx ev_oc_id],ev_mkt_id) $ev_mkt_id
		}

		# build up an ordered list of favourites to use as substitutes
		set FAV($ev_mkt_id) [list]

		# Option 1: See if the feed has filled in the substitute IDs for the market
		set stmt [stl_qry_prepare GET_SUBST_INFO_FROM_MKT]
		set res [inf_exec_stmt $stmt $ev_mkt_id]
		if {[db_get_nrows $res] > 0} {
			set n 1
			while {[lsearch -exact [db_get_colnames $res] subst_ev_oc_id_$n] != -1 && [db_get_col $res 0 subst_ev_oc_id_$n] != ""} {
				lappend FAV($ev_mkt_id) [db_get_col $res 0 subst_ev_oc_id_$n]
				incr n
			}
		}
		db_close $res

		# Option 2: See if the unnamed favourite selections have the relevant info
		if {![llength $FAV($ev_mkt_id)]} {
			set stmt [stl_qry_prepare GET_SUBST_INFO_FROM_UNNAMED_FAVS]
			set res [inf_exec_stmt $stmt $ev_mkt_id]
			array set subst [array unset subst]
			for {set idx 0} {$idx < [db_get_nrows $res]} {incr idx} {
				if {[info exists subst([db_get_col $res $idx fav_status])]} {
					lappend subst([db_get_col $res $idx fav_status]) [db_get_col $res $idx ev_oc_id]
				} else {
					set subst([db_get_col $res $idx fav_status]) [list [db_get_col $res $idx ev_oc_id]]
				}
			}
			db_close $res

			# select a first favourite
			if {[info exists subst(1)]} {
				# we have a first favourite listed
				set FAV($ev_mkt_id) [concat $FAV($ev_mkt_id) $subst(1)]
			} elseif {[info exists subst(L)]} {
				# no first favourite listed, it must have lost - stick in the first loser
				lappend FAV($ev_mkt_id) [lindex $subst(L) 0]
			} elseif {[info exists subst(V)]} {
				# no placed first favourite and no losers?! - the favourite must have gone void!
				lappend FAV($ev_mkt_id) [lindex $subst(V) 0]
			}

			# second verse, same as the first...
			if {[info exists subst(2)]} {
				set FAV($ev_mkt_id) [concat $FAV($ev_mkt_id) $subst(2)]
			} elseif {[info exists subst(L)]} {
				lappend FAV($ev_mkt_id) [lindex $subst(L) 0]
			} elseif {[info exists subst(V)]} {
				lappend FAV($ev_mkt_id) [lindex $subst(V) 0]
			}
		}

		# Option 3: Calculate the favourites from what odds we have
		# Note: This code -should- never get called unless something very screwy happens to the race
		if {![llength $FAV($ev_mkt_id)]} {
			set stmt [stl_qry_prepare GET_SUBST_INFO_FROM_ODDS]
			set res [inf_exec_stmt $stmt $ev_mkt_id]
			set odds [list]
			for {set idx 0} {$idx < [db_get_nrows $res]} {incr idx} {
				lappend odds [list]
				foreach col {ev_oc_id runner_num odds} {
					set odds [lreplace $odds end end [concat [lindex $odds end] [db_get_col $res $idx $col]]]
				}
			}
			set odds [lsort -command compare_odds $odds]
			foreach item $odds {
				lappend FAV($ev_mkt_id) [lindex $item 0]
			}
		}

		set FAV($ev_mkt_id,count) [llength $FAV($ev_mkt_id)]
	}


	# Get information about the dividends relating to this pool
	set stmt [stl_qry_prepare GET_DIVIDEND_INFO]
	set res [inf_exec_stmt $stmt $pool_id]

	set nrows [db_get_nrows $res]

	set POOL($pool_id,div,num_divs) $nrows

	for {set idx 0} {$idx < $nrows} {incr idx} {
		set pk "$pool_id,div,$idx"

		set num_legs [db_get_col $res $idx num_legs]

		# Round dividends to 5 decimal places
		set POOL($pk,dividend) [format "%0.5f" [db_get_col $res $idx dividend]]
		set POOL($pk,num_legs) $num_legs
		set POOL($pk,field) 0
		set POOL($pk,legs_avail) 0
		set POOL($pk,consolation) [expr {([db_get_col $res $idx is_consolation] == "Y") ? 1 : 0}]

		for {set col 1} {$col <= 9} {incr col} {
			set leg [db_get_col $res $idx leg_$col]
			regsub -all {[ \t]+} $leg "" leg

			if {$leg != {}} {
				incr POOL($pk,legs_avail)

				# If this isn't a consolation and we find an F we need
				# to mark this a field bet
				if {[string first "F" $leg] != -1} {
					# Replace the F's with *'s so that string match will
					# match anything
					set leg [string map {F *} $leg]

					if {$POOL($pk,consolation) != 1} {
						set POOL($pk,field) 1
					}
				}

				set leg [split [string trim $leg ,] ,]

				if {$POOL($pool_id,leg_type) == "U"} {
					# If this is an unordered bet type it's a field i.e. contains *'s
					# then we whip out the *'s, and order what's left (if anything)
					# If there is nothing after we've whipped out the *'s then we put
					# the one * back in... could probably check for 1 * initially...
					# why don't you do it for me.
					while {[set fpos [lsearch -exact $leg {*}]] != -1} {
						set leg [lreplace $leg $fpos $fpos]
					}
					if {$leg != {}} {
					set POOL($pk,leg_$col) [lsort -integer -increasing $leg]
				} else {
						set POOL($pk,leg_$col) {*}
					}
				} else {
					set POOL($pk,leg_$col) $leg
				}

				log 50 "POOL($pk,leg_$col) = $POOL($pk,leg_$col)"
			} else {
				break
			}
		}
	}

	db_close $res

	# Get the runners (i.e. excluding non-runners) per leg
	set stmt [stl_qry_prepare GET_RUNNERS_PER_LEG]
	set res [inf_exec_stmt $stmt $pool_id]

	# Set defaults for each leg. I do this 'cause I don't know whether
	# I'm going to get back information about no legs, 1 leg or lots of
	# legs.
	for {set leg 1} {$leg <= $POOL($pool_id,num_legs)} {incr leg} {
		set POOL($pool_id,$leg,runners) 0
	}

	if {[set nrows [db_get_nrows $res]] < 1} {
		log 5 "no runners in this pool"
		return 1
	}

	for {set row 0} {$row < $nrows} {incr row} {
		set POOL($pool_id,[db_get_col $res $row leg_num],runners) [db_get_col $res $row num_runners]
	}

	db_close $res

	# Get all the bet info for each of the bets for this pool
	lappend POOL(pools) $pool_id

	return 1
}

############################################################
# SQL
############################################################

set STL_QRY(GET_POOL_BET_IDS,sql) {
	execute procedure pGetPoolBetIds(p_pool_id = ?);
}

# Get the information about the bet, not selection info
set STL_QRY(GET_POOL_BETS,sql) {
	select distinct
		b.pool_bet_id,
		b.cr_date,
		to_char(b.cr_date, "%Y%m%d%H%M%S") bet_date,
		b.bet_type,
		b.acct_id,
		b.stake,
		b.ccy_stake_per_line,
		b.max_payout,
		b.num_selns,
		b.num_legs,
		b.leg_type,
		b.num_lines,
		b.receipt,
		b.allup,
		b.desc,
				b.source,
		a.ccy_code cust_ccy
	from
		tPoolBet b,
		tAcct a
	where
		b.pool_bet_id in (
					 select
					 	pool_bet_id
					 from
					 	tmpPools
					 )
	and
		a.acct_id = b.acct_id
	order by
		b.pool_bet_id asc
}

# Get the selection information for the bets
set STL_QRY(GET_POOL_BET_DETAILS,sql) {
	select
		o.pool_bet_id,
		o.pool_id,
		o.leg_no,
		o.part_no,
		o.ev_oc_id,
		o.banker_info,
		c.result,
		c.runner_num,
		c.ev_mkt_id,
		c.fb_result,
		s.ccy_code bet_ccy,
		decode(c.result_conf, 'N', 'N',
			   decode(m.result_conf, 'N', 'N',
					  decode(e.result_conf, 'N', 'N', 'Y'))) result_conf
	from
		tPBet o,
		tEv e,
		tEvMkt m,
		tEvOc c,
		tPool p,
		tPoolSource s
	where
		o.pool_bet_id in (
					 select
					 	pool_bet_id
					 from
					 	tmpPools
					 )
	and
		p.pool_id = o.pool_id
	and
		s.pool_source_id = p.pool_source_id
	and
		c.ev_oc_id = o.ev_oc_id
	and
		m.ev_mkt_id = c.ev_mkt_id
	and
		e.ev_id = m.ev_id
	order by
		o.pool_bet_id asc,
		o.pool_id asc,
		o.leg_no asc,
		o.part_no asc
}

#
# ----------------------------------------------------------------------------
# Get pools information
# ----------------------------------------------------------------------------
#
set STL_QRY(GET_POOL_INFO,sql) {
	select
		p.pool_id,
		p.status,
		p.is_void pool_void,
		p.settled pool_settled,
		p.rec_dividend,
		t.num_legs,
		t.leg_type,
		t.bet_type,
		t.num_subs,
		t.min_runners,
		t.num_picks,
		t.grouped_divs,
		m.ev_mkt_id,
		m.leg_num,
		k.result_conf,
		e.is_void leg_void,
		t.void_action,
		s.ccy_code
	from
		tPool p,
		tPoolType t,
		tPoolSource s,
		tPoolMkt m,
		tEvMkt k,
		tEv e
	where
		p.pool_id = ?
	and
		t.pool_type_id = p.pool_type_id
	and
		t.pool_source_id = p.pool_source_id
	and
		s.pool_source_id = t.pool_source_id
	and
		k.ev_mkt_id = m.ev_mkt_id
	and
		e.ev_id = k.ev_id
	and
		m.pool_id = p.pool_id
}

#
# ----------------------------------------------------------------------------
# Get favourite information
# ----------------------------------------------------------------------------
#

set STL_QRY(GET_RUNNER_NUMS_BY_MKT,sql) {
	select
		o.ev_oc_id,
				o.runner_num
	from
		tevoc o
	where
		o.ev_mkt_id = ?
}

set STL_QRY(GET_SUBST_INFO_FROM_MKT,sql) {
	select
		m.subst_ev_oc_id_1,
		m.subst_ev_oc_id_2,
		m.subst_ev_oc_id_3
	from
		tevmkt m
	where
		m.ev_mkt_id = ?
}

set STL_QRY(GET_SUBST_INFO_FROM_UNNAMED_FAVS,sql) {
	select
		o1.runner_num,
		o1.ev_oc_id,
		nvl(o2.fb_result, o1.result) as fav_status
	from
		tEvOc o1, outer tEvOc o2
	where
		o1.ev_mkt_id = ?
	and
		o1.fb_result = '-'
	and
		o1.runner_num is not null
	and
		o2.ev_mkt_id = o1.ev_mkt_id
	and
		o2.fb_result != '-'
	and
		o2.runner_num = o1.runner_num
	order by 1
}

set STL_QRY(GET_SUBST_INFO_FROM_ODDS,sql) {
	select
		o.ev_oc_id,
		o.runner_num,
		nvl(1 + (o.sp_num / o.sp_den), 1 + (o.lp_num / o.lp_den)) as odds
	from
		tEvOc o
	where
		o.ev_mkt_id = ?
	and
		o.fb_result = '-'
}


#
# ----------------------------------------------------------------------------
# Get dividend information
# ----------------------------------------------------------------------------
#
set STL_QRY(GET_DIVIDEND_INFO,sql) {
	select
		d.num_legs,
		d.dividend / s.dividend_unit as dividend,
		d.leg_1,
		d.leg_2,
		d.leg_3,
		d.leg_4,
		d.leg_5,
		d.leg_6,
		d.leg_7,
		d.leg_8,
		d.leg_9,
		is_consolation
	from
		tPoolDividend d,
		tPool p,
		tPoolSource s
	where
		d.pool_id = ?
	and
		p.pool_id = d.pool_id
	and
		s.pool_source_id = p.pool_source_id
}

#
# ----------------------------------------------------------------------------
# Get runners information
# ----------------------------------------------------------------------------
#
set STL_QRY(GET_RUNNERS_PER_LEG,sql) {
	select
		p.leg_num,
		p.ev_mkt_id,
		count(o.ev_oc_id) num_runners
	from
		tEvOc o,
		tPoolMkt p
	where
		p.pool_id = ?
	and
		p.ev_mkt_id = o.ev_mkt_id
	and
		o.result not in ('V', '-')
	group by
		p.leg_num, p.ev_mkt_id
}

#
# ----------------------------------------------------------------------------
# Sets all settled flags related to this pool bet
# ----------------------------------------------------------------------------
#
set STL_QRY(SETTLE_POOL,sql) {
	execute procedure pSetPoolSettled(p_adminuser = ?, p_pool_id = ?)
}

#
# ----------------------------------------------------------------------------
# Settlement for win/void bets - the procedure which is called makes
# all the necessary account postings and updates the bet
# ----------------------------------------------------------------------------
#
set STL_QRY(BET_WIN_REFUND,sql) {
	execute procedure pSettlePoolBet(
		p_adminuser        = ?,
		p_pool_bet_id      = ?,
		p_num_lines_win    = ?,
		p_num_lines_lose   = ?,
		p_num_lines_void   = ?,
		p_winnings         = ?,
		p_refund           = ?,
		p_settle_info      = ?,
		p_enable_parking   = ?,
		p_park_by_winnings = ?
	)
}

set STL_QRY(GET_UNSETTLED_POOLS,sql) {
	select
		pool_id
	from
		tPool p
	where
		settled      = 'N'
	and (rec_dividend = 'Y' or is_void = 'Y')
	and result_conf  = 'Y'
	and not exists (select pool_dividend_id
					from tPoolDividend d
					where d.pool_id = p.pool_id
					and   d.confirmed = 'N')
}

set STL_QRY(GET_POOLS_FOR_EVENT,sql) {
	select p.pool_id
	from tPool p,
		 tPoolMkt pm,
		 tEvMkt em
	where em.ev_id     = ?
	and em.ev_mkt_id   = pm.ev_mkt_id
	and pm.pool_id     = p.pool_id
	and p.settled      = 'N'
	and (p.rec_dividend = 'Y' or p.is_void = 'Y')
	and p.result_conf  = 'Y'
	and not exists (select pool_dividend_id
					from tPoolDividend d
					where d.pool_id = p.pool_id
					and   d.confirmed = 'N')
}

set STL_QRY(GET_POOLS_FOR_MARKET,sql) {
	select p.pool_id
	from tPool p,
		 tPoolMkt pm
	where pm.ev_mkt_id     = ?
	and pm.pool_id     = p.pool_id
	and p.settled      = 'N'
	and (p.rec_dividend = 'Y' or p.is_void = 'Y')
	and p.result_conf  = 'Y'
	and not exists (select pool_dividend_id
					from tPoolDividend d
					where d.pool_id = p.pool_id
					and   d.confirmed = 'N')
}

# This is used just to populate the temporary
# table on the occassion when only 1 bet is
# being settled rather than a whole pool
set STL_QRY(GET_POOL_BET_IDS_FOR_BET,sql) {
	select distinct
		u.pool_bet_id bet_id,
		o2.pool_id
	from
		tPoolBetUnstl u,
		tPoolBet b,
		tPBet o1,
		tPBet o2
	where
		o1.pool_bet_id = ?
	and
		u.pool_bet_id = o1.pool_bet_id
	and
		b.pool_bet_id = u.pool_bet_id
	and
		o2.pool_bet_id = b.pool_bet_id
	and
		'N' not in (
					select
						decode(c.result_conf||m.result_conf||e.result_conf, 'YYY', 'Y', 'N') as result_conf
					from
						tPBet o,
						tEvOc c,
						tEvMkt m,
						tEv e
					where
						c.ev_mkt_id = m.ev_mkt_id
					and
						m.ev_id = e.ev_id
					and
						c.ev_oc_id = o.ev_oc_id
					and
						o.pool_bet_id = b.pool_bet_id
					)
	into
		temp tmpPools
}

set STL_QRY(DROP_TEMPORARY,sql) {
	execute procedure pDropTmpPools();
}

set STL_QRY(SET_SETTLED,sql) {
	execute procedure pSetSettled(
		p_adminuser = ?,
		p_obj_type = ?,
		p_obj_id = ?
	)
}


}

#rename proc _old_proc
#rename _proc proc
