# $Id: co_favourite_redns.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $

# This namespace will provide methods for wrapping around various stored
# procs for generating numbers to go into the DH Reduction values for
# selections, which will also combine Co-Favourite reductions as appropriate

# Note the careful selection of language in these procedures
# "Joint Favourites" refers to there being 2 runners with a given price
# "Co-Favourites" refers to there being > 2 runners with a given price

# in the case of a race with Joint/Co First Favs, the Unnamed Fav and Unnamed 2nd Fav
# selections are to be the exact same thing.

# open namespace

namespace eval co_favourite_redns {

variable MARKET
variable ADMINUSER


package require util_log
package require util_log_compat
ob_log::init

# close namespace
}

proc co_favourite_redns::init {{adminuser ""}} {

	variable MARKET
	variable ADMINUSER

	catch {unset MARKET}

	_init_db_qrys

	# keep track of the adminuser that's being used -- this is to make the
	# use of this library from SiS and PA a little neater

	if {$adminuser != ""} {
		set ADMINUSER $adminuser
	}

	OT_LogWrite 10 "co_favourite_redns initialised"

}

proc co_favourite_redns::_init_db_qrys {} {

	# get the selections from a market, ignoring UF/U2F selections (fb_result <> '-')
	# order them by price, asc
	OB_db::db_store_qry get_mkt_ocs {
		select
			ev_oc_id,
			result,
			place,
			NVL(sp_num,lp_num) as sp_num,
			NVL(sp_den,lp_den) as sp_den,
			NVL(sp_num,lp_num)/NVL(sp_den,lp_den)
		from
			tEvOc
		where
			ev_mkt_id = ?
		and     fb_result = '-'
		and
		(
			(sp_num is not null and sp_den is not null)
			or
			(lp_num is not null and lp_den is not null)
		)

		order by 6, place
	}

	# Need to know how many unnamed favourite selections there are in a market
	# can get this from the highest fb_result
	OB_db::db_store_qry get_mkt_uf_num {
		select
			max(fb_result)
		from
			tEvOc
		where
			ev_mkt_id = ?
		and     fb_result <> '-'
	}

	OB_db::db_store_qry get_mkt_places {
		select
			1 + ew_places
		from
			tEvMkt
		where
			ev_mkt_id = ?
	}

	# get an ev_oc_id based on fb_result - use it to get the UF/U2F id
	OB_db::db_store_qry get_uf_id {
		select
			ev_oc_id
		from
			tEvOc
		where
			ev_mkt_id = ?
		and     fb_result = ?
	}

	# use this to check if we actually need to update the result
	OB_db::db_store_qry get_oc_results {
		select
			ev_oc_id,
			result,
			place,
			sp_num,
			sp_den
		from
			tEvOc
		where
			ev_oc_id = ?
	}

	# method to update the result, sp_num and sp_den of an OC
	OB_db::db_store_qry set_oc_results {
		execute procedure pSetEvOcResult (
			p_adminuser = ?,
			p_ev_oc_id  = ?,
			p_result    = ?,
			p_place     = ?,
			p_sp_num    = ?,
			p_sp_den    = ?
		)
	}

	# set the Dead Heat Reduction
	OB_db::db_store_qry set_dh_redn {
		execute procedure pSetDeadHeatRedn (
			p_adminuser = ?,
			p_ev_oc_id  = ?,
			p_dh_type   = ?,
			p_dh_num    = ?,
			p_dh_den    = ?,
			p_result    = ?
		)
	}

	# get the ew factors for the market
	OB_db::db_store_qry get_ew_factors {
		select
			ew_fac_num,
			ew_fac_den
		from
			tEvMkt
		where
			ev_mkt_id = ?
	}

	# get the ew places for the market
	OB_db::db_store_qry get_ew_places2 {
		select
			ew_places
		from
			tEvMkt
		where
			ev_mkt_id = ?
	}
}


# set up the basic variables we'll need later for a market
proc co_favourite_redns::_init_market {ev_mkt_id} {

	variable MARKET

	catch {unset MARKET}

	# there will probably be more to add here
	foreach {var default} {
		first_co_favs  0
		second_co_favs 0
		win            0
		runners        0
	} {
		set MARKET($ev_mkt_id,$var) $default
	}

	# find out how many UF selections this has
	if {[catch {set rs [db_exec_qry get_mkt_uf_num $ev_mkt_id]} msg]} {
		set err_msg "failed to find number of UF selections: $msg"
		OT_LogWrite 1 $err_msg
		error $err_msg
	}

	set MARKET(ev_mkt_id) $ev_mkt_id
	set MARKET($ev_mkt_id,num_ufs) [db_get_coln $rs 0 0]

	db_close $rs

	if {[catch {set rs [db_exec_qry get_mkt_places $ev_mkt_id]} msg]} {
		set err_msg "failed to find number of places: $msg"
		OT_LogWrite 1 $err_msg
		error $err_msg
	}

	for {set i 2} {$i <= [db_get_coln $rs 0 0]} {incr i} {
		# remember we handle win (place,1) specially
		set MARKET($ev_mkt_id,places,$i) 0
	}

	db_close $rs

	if {[catch {set rs [db_exec_qry get_ew_factors $ev_mkt_id]} msg]} {
		set err_msg "failed to find ew_factors: $msg"
		OT_LogWrite 1 $err_msg
		error $err_msg
	}

	if {[db_get_nrows $rs]} {
		set MARKET($ev_mkt_id,ew_num) [db_get_col $rs 0 ew_fac_num]
		set MARKET($ev_mkt_id,ew_den) [db_get_col $rs 0 ew_fac_den]
	}

	db_close $rs

}


# returning an empty list from this proc indicates that no co-favourites were found
# and as such, normal Dead Heat reductions apply
# otherwise, will return an even-length list of numerators and denominators
# for each of the unnamed favourites in turn
proc co_favourite_redns::_load_market_ocs {ev_mkt_id {fav_no_limit 2}} {

	variable MARKET

	_init_market $ev_mkt_id

	# sanity check
	if {$MARKET($ev_mkt_id,num_ufs) == ""} {
		# this implies no UF selections: exit cleanly
		return 1
	}

	set fav_no_limit $MARKET($ev_mkt_id,num_ufs)


	OT_LogWrite 15 "co_favourite_redns::_load_market_ocs: loading market $ev_mkt_id"
	# get the selections, results and SPs for the market
	if {[catch {set rs [db_exec_qry get_mkt_ocs $ev_mkt_id]} msg]} {
		OT_LogWrite 1 "failed to retrieve selections: $msg"
		return 0
	}

	set MARKET($ev_mkt_id,runners) [db_get_nrows $rs]

	if {![db_get_nrows $rs]} {
		# no rows found, exit cleanly
		db_close $rs
		return 1
	}

	# get the ew_places from the db
	if {[catch {set prs [db_exec_qry get_ew_places2 $ev_mkt_id]} msg]} {
		set err_msg "failed to find number of ew places: $msg"
		OT_LogWrite 1 $err_msg
		error $err_msg
	}

	if {[db_get_nrows $prs]} {
		set ew_places [db_get_col $prs 0 ew_places]
	}
	db_close $prs


	# grab all the data into the array
	# start processing them. REMEMBER: the selections are in price order
	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		# capture the data for later
		foreach col {
			ev_oc_id
			result
			place
			sp_num
			sp_den
		} {
			set MARKET($ev_mkt_id,$i,$col) [db_get_col $rs $i $col]
		}

		if {$MARKET($ev_mkt_id,$i,result) == "P" && $MARKET($ev_mkt_id,$i,place) > $ew_places} {
			set MARKET($ev_mkt_id,$i,result) "L"
		}

		# start aggregating the results, so that we know the overall totals of
		# winners, places, losers and voids
		# remember - if the result is '-' we don't want to deal with this market
		# and so return 0
		# we also want to remember to make sure we keep the overall market totals
		# complete, but limit the favourite specific totals to only the favourites
		# seems obvious, but the double inspection of the results makes it unclear

		switch -- $MARKET($ev_mkt_id,$i,result) {
			"-" {
				# unset result: can't really deal with this if there are unset results
				# shutdown
				db_close $rs
				return 0
			}
			W {
				# we have a winner
				incr MARKET($ev_mkt_id,win)
			}
			P {
				# need to inspect which place
				if {$MARKET($ev_mkt_id,$i,place) <= $ew_places} {
					incr MARKET($ev_mkt_id,places,$MARKET($ev_mkt_id,$i,place))
				}
			}

		}
	}

	# loop vars
	set price_idx 0
	for {set i 0} {$i < [db_get_nrows $rs] && $price_idx < $MARKET($ev_mkt_id,num_ufs) && $price_idx < $fav_no_limit} {incr i} {
		# inspect the results

		# let's use a key
		set oc_key   $ev_mkt_id,$i

		# compare this price to the previous, unless we're at 0
		if {$i} {

			if {$MARKET($oc_key,sp_num) == $MARKET($ev_mkt_id,[expr {$i - 1}],sp_num)
				&& $MARKET($oc_key,sp_den) == $MARKET($ev_mkt_id,[expr {$i - 1}],sp_den)} {

				# co-favs!
				# was it the first?
				if {!$price_idx} {
					OT_LogWrite 55 "co_favourite_redns: Found Joint First Favs in mkt $ev_mkt_id"
					set MARKET($ev_mkt_id,first_co_favs) 1

				} elseif {!$MARKET($ev_mkt_id,first_co_favs)} {
					# we only want to declare there to be co-favourites if
					# we don't have joint favourites
					OT_LogWrite 55 "co_favourite_redns: Found Joint Second Favs in mkt $ev_mkt_id"
					set MARKET($ev_mkt_id,second_co_favs) 1
				} else {
					# exit, as we've got all our favourites already
					break
				}

			} else {
				# if this is a new price, then check to see if we've already declared that we have
				# joint or co favourites
				if {$MARKET($ev_mkt_id,first_co_favs) || $MARKET($ev_mkt_id,second_co_favs)} {
					OT_LogWrite 15 "co_favourite_redns: already have joint/co favs"
					break
				} else {
					incr price_idx
					# this might work:
					if {$price_idx == $MARKET($ev_mkt_id,num_ufs)} {
						# if we've got the right number of prices now, quit
						OT_LogWrite 55 "co_favourite_redns: found enough favourites now: breaking"
						break
					}
				}
				#
			}
		}

		# keep track of the highest price_idx we got to, for later
		set MARKET($ev_mkt_id,max_price_idx) $price_idx

		# let's use a key, rather than repeating the same long-winded array hash every time
		set fav_key $ev_mkt_id,favs,$price_idx

		# we can only get here if :
		# a) we're on the first selection
		# or b) we've ensured we've not exceeded the allowed number of favs
		lappend MARKET($fav_key,idxs) $i

		# copy this favourite's price
		set MARKET($fav_key,sp_num) $MARKET($oc_key,sp_num)
		set MARKET($fav_key,sp_den) $MARKET($oc_key,sp_den)

		# copy the ew factors to the favourite
		set MARKET($fav_key,ew_num) $MARKET($ev_mkt_id,ew_num)
		set MARKET($fav_key,ew_den) $MARKET($ev_mkt_id,ew_den)

		# inspect the result
		if {[lsearch {W P L V} $MARKET($oc_key,result)] != -1} {
			# this is uuuuuuugly
			# handle P slightly differently
			if {$MARKET($oc_key,result) == "P"} {
				# need to include *which* place it was

				if {![info exists MARKET($fav_key,P,$MARKET($oc_key,place))]} {
					set MARKET($fav_key,P,$MARKET($oc_key,place)) 1
					set MARKET($fav_key,$MARKET($oc_key,result)) 1
				} else {
					incr MARKET($fav_key,P,$MARKET($oc_key,place))
					incr MARKET($fav_key,$MARKET($oc_key,result))
				}

			} elseif {![info exists MARKET($fav_key,$MARKET($oc_key,result))]} {
				set MARKET($fav_key,$MARKET($oc_key,result)) 1
			} else {
				incr MARKET($fav_key,$MARKET($oc_key,result))
			}

			# special case for P: we need to record the worst placed Fav
			if {![info exists MARKET($fav_key,max_place)] ||
				$MARKET($oc_key,place) > $MARKET($fav_key,max_place)} {
					set MARKET($fav_key,max_place) $MARKET($oc_key,place)
			}

			# make sure we put the result in the array somewhere useful
			# if it's a better result
			# hmm this is a bit trickier
			# we'll have one of W P L or V, and we want that order of precedence
			if {![info exists MARKET($fav_key,result)] ||
				[lsearch {V L P W} $MARKET($oc_key,result)] > [lsearch {V L P W} $MARKET($fav_key,result)]} {
				set MARKET($fav_key,result) $MARKET($oc_key,result)
			}

			# if it's a better place, store it
			if {![info exists MARKET($fav_key,place)] ||
				$MARKET($fav_key,place) == "" ||
				($MARKET($oc_key,place) != "" && $MARKET($oc_key,place) < $MARKET($fav_key,place))} {

				set MARKET($fav_key,place) $MARKET($oc_key,place)
			}

		} else {
			# unhandled result type
			OT_LogWrite 1 "Unhandled result type"
			return 0
		}

	}

	# sanity check please: should never have both joint favs and co favs
	# this should never actually be reachable due to break clauses, but just in case...
	if {$MARKET($ev_mkt_id,first_co_favs) && $MARKET($ev_mkt_id,second_co_favs)} {
		OT_LogWrite 1 "co_favourite_redns::_load_market_ocs: have both Joint Favs AND Co-Favs: this is not good"
		db_close $rs
		return 0
	}

	# EARLY STOP CHECK

	# we can stop here if there are no co-favs, and follow normal protocol elsewhere
	if {!$MARKET($ev_mkt_id,first_co_favs) && !$MARKET($ev_mkt_id,second_co_favs)} {
		OT_LogWrite 55 "Leaving _load_market_ocs early: have neither first_co_favs nor second_co_favs"
		db_close $rs
		return  1
	}

	set MARKET($ev_mkt_id,num_ocs) [db_get_nrows $rs]

	db_close $rs


	# so at this point, we know what kind of favourites we have,
	# and we have an idea of what results they got.
	# we have a count of the number of favs that voided, lost, won and placed
	# now we need to inspect the results and places for dead heats

	# the important parts of our array at this point tell us:
	# total horses that won
	# total horses that placed
	# whether we have joint favs or co favs
	# how many of those Won or Placed
	# the worst placed horse (if any) for any co/joint favs


	for {set f 0} {$f <= $MARKET($ev_mkt_id,max_price_idx)} {incr f} {
		set fav_key $ev_mkt_id,favs,$f

		foreach idx $MARKET($fav_key,idxs) {
			# check to see if there were more than one horse
			# with the same result as each of these horses
			if {$MARKET($ev_mkt_id,$idx,result) == "W"} {
				# if it won, set record either 0 if it was a clear win
				# or the nr of horses that DH
				if {$MARKET($ev_mkt_id,win) > 1} {
					set MARKET($fav_key,DH,W,nr_dh) $MARKET($ev_mkt_id,win)
					set MARKET($fav_key,DH,W,favs_dh) $MARKET($fav_key,W)
				}

			} elseif {$MARKET($ev_mkt_id,$idx,result) == "P"} {
				# Places are a bit special
				# we only care if the co-fav in max_place dead heated
				set place $MARKET($fav_key,max_place)

				set MARKET($fav_key,DH,P,nr_dh) \
					[expr {$MARKET($ev_mkt_id,places,$place) > 1 ? $MARKET($ev_mkt_id,places,$place) : 0}]


				set MARKET($fav_key,DH,P,favs_dh) \
					[expr {[info exists MARKET($fav_key,P,$place)] && $MARKET($fav_key,P,$place) > 1 ?
						$MARKET($fav_key,P,$place) : 0
					}]

			}
			# otherwise, we don't care
		}

		# so now we have all the information for this unnamed favourite selection

		foreach key [list \
			$fav_key,V \
			$fav_key,L \
			$fav_key,W \
			$fav_key,P \
		] {
			if {![info exists MARKET($key)]} {
				set MARKET($key) 0
			}
		}

		# we can use the magic formula finally!
		foreach dh_type {W P} {
			if {[catch {set ret [combine_dh_cf_reductions $fav_key $dh_type]} msg]} {
				OT_LogWrite 1 "Failed to combine DH CF reductions: $msg"
				return 0
			}

			foreach {dh_num dh_den} $ret {
				set MARKET($fav_key,DH,$dh_type,dh_num) $dh_num
				set MARKET($fav_key,DH,$dh_type,dh_den) $dh_den
			}
		}

	}

	return 1
}

# get the ev_oc_id for the given fb_result and ev_mkt_id and shove it in MARKET
proc co_favourite_redns::_set_uf_id {ev_mkt_id fb_result} {

	variable MARKET

	if {[catch {set rs [db_exec_qry get_uf_id $ev_mkt_id $fb_result]} msg]} {
		OT_LogWrite 1 "failed to retrieve Unnamed Fav ID: $msg"
		return 0
	}

	if {![db_get_nrows $rs]} {
		db_close $rs
		OT_LogWrite 5 "No UF selection found for given ev_mkt_id ($ev_mkt_id) and fb_result ($fb_result)"
		return 0
	}

	set MARKET($ev_mkt_id,favs,[expr {$fb_result - 1}],ev_oc_id) [db_get_col $rs 0 ev_oc_id]

	db_close $rs

	return 1
}

# TODO: Need to sanitise the output from this and the underlying procs, to ensure
# that normal cases, such as not all the results being in, generate the expected
# return values throughout.

# Basically, it should only ever return 0 on failure, otherwise 1

# unexpectedly normal situations include:
#  - incomplete set of results for market
#  - no UF selections
#  - any more?

# this proc will actually update the UF and U2F selections for the given ev_mkt_id
proc co_favourite_redns::upd_mkt_unnamed_favs {ev_mkt_id {fav_no_limit 2}} {
# PRE : there must be at least one UF selection (fb_result = 1|2)

	variable MARKET
	variable ADMINUSER

	OT_LogWrite 15 "co_favourite_redns::upd_mkt_unnamed_favs: Starting"

	if {![_load_market_ocs $ev_mkt_id $fav_no_limit]} {
		OT_LogWrite 1 "Failed to load market $ev_mkt_id"
		return 0
	}

	if {!$MARKET($ev_mkt_id,runners)} {
		# no runners in this market
		OT_LogWrite 5 "There are no runners in this market"
		return 0
	}

	# need to know (as a related set) for each UF
	# ev_oc_id
	# fb_result > this comes from the price_idx
	# (best in case of Co-Favs) result
	# (best in case of Co-Favs) place
	# dh_num
	# dh_den > these are calculated as combined with EW, CF and DH reductions

	set num_favs $MARKET($ev_mkt_id,num_ufs)

	# using the fav_no_limit enables us to control whether we should be looking
	# anything more than 1 UF
	for {set f 0} {$f < $num_favs && $f < $fav_no_limit} {incr f} {

		# this might appear a little mad
		# we need a mechanism to make sure that we copy over the data from the UF to the U2F selection
		# in the case where we have joint favs
		# so, we use 2 keys: read_fav_key and write_fav_key
		# we use write_fav_key to lock onto the correct selection for the UF to update
		# we use read_fav_key to make sure we have the data from the correct UF selection
		if {!$f} {
			# first row
			set read_fav_key $ev_mkt_id,favs,$f
		} elseif {!$MARKET($ev_mkt_id,first_co_favs)} {
			# if we've not got joint favs, do move onto the next favourite
			# otherwise stick with the first one
			set read_fav_key $ev_mkt_id,favs,$f
		}
		set write_fav_key $ev_mkt_id,favs,$f

		# get the ev_oc_id
		if {![_set_uf_id $ev_mkt_id [expr {$f + 1}]]} {
			return 0
		}

		# set the result, place, sp_num, sp_den
		# first, double check we're not trying to set the same values that are already in the db
		# this might happen if something is spinning, and it generates annoying amounts of audit rows
		# unnecessarily
		if {[catch {set get_rs [db_exec_qry get_oc_results \
			$MARKET($write_fav_key,ev_oc_id)\
		]} msg]} {
			OT_LogWrite 1 "Failed to get results for UF in mkt $ev_mkt_id: $msg"
			return 0
		}
		if {
			$MARKET($read_fav_key,result) != [db_get_col $get_rs 0 result] ||
			$MARKET($read_fav_key,place)  != [db_get_col $get_rs 0 place]  ||
			$MARKET($read_fav_key,sp_num) != [db_get_col $get_rs 0 sp_num] ||
			$MARKET($read_fav_key,sp_den) != [db_get_col $get_rs 0 sp_den]
		} {


			# remember to use the write_fav_key's ev_oc_id, but the data from the read_fav_key
			if {[catch {set rs [db_exec_qry set_oc_results \
				$ADMINUSER \
				$MARKET($write_fav_key,ev_oc_id) \
				$MARKET($read_fav_key,result) \
				$MARKET($read_fav_key,place) \
				$MARKET($read_fav_key,sp_num) \
				$MARKET($read_fav_key,sp_den) \
			]} msg]} {

				OT_LogWrite 1 "Failed to set results for UF in mkt $ev_mkt_id: $msg"
				return 0
			}

		}

		db_close $get_rs

		foreach dh_type {W P} {
			# set the DH redn as we calculated, if we calculated anything
			if {[info exists MARKET($read_fav_key,DH,$dh_type,dh_num)]} {
				if {[catch {set rs [db_exec_qry set_dh_redn \
					$ADMINUSER \
					$MARKET($write_fav_key,ev_oc_id) \
					$dh_type \
					$MARKET($read_fav_key,DH,$dh_type,dh_num) \
					$MARKET($read_fav_key,DH,$dh_type,dh_den) \
					$MARKET($read_fav_key,result) \
				]} msg]} {

					OT_LogWrite 1 "Failed to set DH Redn for UF in mkt $ev_mkt_id: $msg"
					return 0
				}
			} else {
				OT_LogWrite 55 "Not setting DH Reduction for fav $read_fav_key"
			}
		}

	}

	return 1

}

# wrapper for _combine_dh_cf_reductions, using MARKET
# tidies up the code above a little
proc co_favourite_redns::combine_dh_cf_reductions {fav_key dh_type} {

	variable MARKET

	OT_LogWrite 1 "combine_cf_dh_reductions: $fav_key $dh_type"

	if {$dh_type == "W"} {
		set loseCount [expr {$MARKET($fav_key,L) + $MARKET($fav_key,P)}]
	} else {
		set loseCount $MARKET($fav_key,L)
	}

	set failed 0

	if {[info exists MARKET($fav_key,idxs)] && [info exists MARKET($fav_key,L)]} {

		if {[info exists MARKET($fav_key,DH,$dh_type,favs_dh)]
			&& [info exists MARKET($fav_key,DH,$dh_type,nr_dh)]} {


			if {[info exists MARKET($fav_key,V)]
				&& [info exists MARKET($fav_key,sp_num)]
				&& [info exists MARKET($fav_key,sp_den)]
				&& [info exists MARKET($fav_key,ew_num)]
				&& [info exists MARKET($fav_key,ew_den)]
			} {
				OT_LogWrite 1 "Calling: _combine_dh_cf_reductions \
					[llength $MARKET($fav_key,idxs)] \
					$loseCount \
					$MARKET($fav_key,DH,$dh_type,favs_dh) \
					$MARKET($fav_key,DH,$dh_type,nr_dh) \
					$MARKET($fav_key,V) \
					$MARKET($fav_key,sp_num) \
					$MARKET($fav_key,sp_den) \
					$MARKET($fav_key,ew_num) \
					$MARKET($fav_key,ew_den) \
				"

				# we have the full data set
				if {[catch {set ret [_combine_dh_cf_reductions \
					[llength $MARKET($fav_key,idxs)] \
					$loseCount \
					$MARKET($fav_key,DH,$dh_type,favs_dh) \
					$MARKET($fav_key,DH,$dh_type,nr_dh) \
					$MARKET($fav_key,V) \
					$MARKET($fav_key,sp_num) \
					$MARKET($fav_key,sp_den) \
					$MARKET($fav_key,ew_num) \
					$MARKET($fav_key,ew_den) \
				]} msg]} {
					OT_LogWrite 1 "combine_cf_dh_reductions failed: $msg"
					set failed 1
				}

				if {!$failed} {
					return $ret
				}
			}

			OT_LogWrite 1 "Calling: _combine_dh_cf_reductions \
				[llength $MARKET($fav_key,idxs)] \
				$loseCount \
				$MARKET($fav_key,DH,$dh_type,favs_dh) \
				$MARKET($fav_key,DH,$dh_type,nr_dh) \
			"

			# 2nd best
			if {[catch {set ret [_combine_dh_cf_reductions \
				[llength $MARKET($fav_key,idxs)] \
				$loseCount \
				$MARKET($fav_key,DH,$dh_type,favs_dh) \
				$MARKET($fav_key,DH,$dh_type,nr_dh) \
			]} msg ]} {
				OT_LogWrite 1 "combine_cf_dh_reductions failed: $msg"
				set failed 1
			} else {
				set failed 0
			}

			if {!$failed} {
				return $ret
			}

		} else {

			if {[info exists MARKET($fav_key,V)]
				&& [info exists MARKET($fav_key,sp_num)]
				&& [info exists MARKET($fav_key,sp_den)]
				&& [info exists MARKET($fav_key,ew_num)]
				&& [info exists MARKET($fav_key,ew_den)]
			} {
				OT_LogWrite 1 "Calling: _combine_dh_cf_reductions \
					[llength $MARKET($fav_key,idxs)] \
					$loseCount \
					0 \
					- \
					$MARKET($fav_key,V) \
					$MARKET($fav_key,sp_num) \
					$MARKET($fav_key,sp_den) \
					$MARKET($fav_key,ew_num) \
					$MARKET($fav_key,ew_den) \
				"

				# we have the full data set
				if {[catch {set ret [_combine_dh_cf_reductions \
					[llength $MARKET($fav_key,idxs)] \
					$loseCount \
					0 \
					- \
					$MARKET($fav_key,V) \
					$MARKET($fav_key,sp_num) \
					$MARKET($fav_key,sp_den) \
					$MARKET($fav_key,ew_num) \
					$MARKET($fav_key,ew_den) \
				]} msg]} {
					OT_LogWrite 1 "combine_cf_dh_reductions failed: $msg"
					set failed 1
				} else {
					set failed 0
				}

				if {!$failed} {
					return $ret
				}
			}
		}

		# reached here: do calc using min info
		if {[catch {set ret [_combine_dh_cf_reductions \
			[llength $MARKET($fav_key,idxs)] \
			$loseCount \
		]} msg]} {
			OT_LogWrite 1 "combine_cf_dh_reductions failed: $msg"
			return [list]
		}
	} else {
		set ret [list]
	}
	# need at least num favs and num favs losing
	return $ret
}


# Normal settlement (see stl_main.tcl) returns the winnings per unit stake as:
#
#   rtn/unit = dh + p.ew.dh.(1-r4/100)
#
# where dh is the dead-heat reduction,
#        p is the selections fractional price,
#       ew is the place/each-way reduction factor,
#   and r4 is the Rule 4 deduction in effect.
#
# We'd like to introduce another term, cf, to factor in the co-favourite deduction thus:
#
#  rtn/unit = dh.cf + p.ew.dh.cf.(1-r4/100)
#
# but lacking anywhere to store it in the DB, we're factoring it into the dead-heat reduction.
#
# We're also ignoring any Rule 4 deduction here because I can't see how an Unnamed Favourite
#  (which can only be bet upon at SP) can have a Rule 4 in effect.

proc co_favourite_redns::_combine_dh_cf_reductions {

	no_of_co_favs

	no_of_losing_co_favs

	{no_of_dead_heating_co_favs 0}
	{no_of_dead_heating_runners -}

	{no_of_void_co_favs 0}
	{fav_price_num      -}
	{fav_price_den      -}
	{place_redn_fac_num -}
	{place_redn_fac_den -}

} {

	# list of numerator and denominator pairs used to make up the final reduction

	set combined_dh_cf_parts [list]

	# if -every- favourite is void, we shouldn't be setting a deduction,
	#   we should be setting the unnamed favourite selection to void

	if {$no_of_void_co_favs == $no_of_co_favs} {
		error "all co favourites are void - unnamed favourite should be settled as void"
	}

	# each normal winning favourite needs a co-favourite deduction of 1/ {no of co favs}

	set no_of_winning_co_favs [expr {
		$no_of_co_favs - $no_of_losing_co_favs - $no_of_void_co_favs -
		$no_of_dead_heating_co_favs
	}]



	lappend combined_dh_cf_parts \
		$no_of_winning_co_favs \
		$no_of_co_favs

	if {$no_of_dead_heating_co_favs} {

		if {[string equal $no_of_dead_heating_runners -]} {
			error "incomplete information for calculating dead-heated favourite deductions"
		}

		# each dead-heated favourite needs a dead-heat reduction of 1/{no of dead-heating runners}
		#   and a co-favourite deduction of 1/{no of co favs}

		lappend combined_dh_cf_parts \
			$no_of_dead_heating_co_favs \
			[expr {$no_of_dead_heating_runners * $no_of_co_favs}]
	} else {
		# add a term equal to zero because we don't have a term for dead-heated favourites
		lappend combined_dh_cf_parts 0 1
	}

	if {$no_of_void_co_favs} {

		if {
			[string equal $fav_price_num      -] ||
			[string equal $fav_price_den      -] ||
			[string equal $place_redn_fac_num -] ||
			[string equal $place_redn_fac_den -]
		} {
			error "incomplete information for calculating void favourite deductions"
		}

		# each void favourite needs a reduction of 1/{no of co favs} to its stake but we
		#   also need to cancel out everything the stake normally gets multiplied by to
		#   produce the winnings because voids -only- return the stake
		#
		#   ie, we need an addition reduction of 1/(1 + {fav price}*{place redn fac})

		set reduce_to_stake_num [expr {
			($fav_price_den * $place_redn_fac_den)
		}]
		set reduce_to_stake_den [expr {
			($fav_price_num * $place_redn_fac_num) +
			($fav_price_den * $place_redn_fac_den)
		}]

		lappend combined_dh_cf_parts \
			[expr {$no_of_void_co_favs * $reduce_to_stake_num}] \
			[expr {$no_of_co_favs      * $reduce_to_stake_den}]

	} else {
		# add a term equal to zero because we don't have a term for void favourites
		lappend combined_dh_cf_parts 0 1

	}
	# cross-multiply to get one numerator and one denominator


	OT_LogWrite 15 $combined_dh_cf_parts

	set combined_dh_cf_num [expr {
		([lindex $combined_dh_cf_parts 0] * [lindex $combined_dh_cf_parts 3] * [lindex $combined_dh_cf_parts 5]) +
		([lindex $combined_dh_cf_parts 2] * [lindex $combined_dh_cf_parts 1] * [lindex $combined_dh_cf_parts 5]) +
		([lindex $combined_dh_cf_parts 4] * [lindex $combined_dh_cf_parts 1] * [lindex $combined_dh_cf_parts 3])
	}]
	set combined_dh_cf_den [expr {
		[lindex $combined_dh_cf_parts 1] *
		[lindex $combined_dh_cf_parts 3] *
		[lindex $combined_dh_cf_parts 5]
	}]

	# calculate the greatest common divisor
	set a $combined_dh_cf_num
	set b $combined_dh_cf_den
	while {[set c [expr {$b % $a}]]} {
		if {$c > $a} {
			set b $c
		} else {
			set b $a
			set a $c
		}
	}
	set gcd $a

	return [list \
		[expr {$combined_dh_cf_num / $gcd}] \
		[expr {$combined_dh_cf_den / $gcd}] \
	]
}

# do the initialisation
# init
