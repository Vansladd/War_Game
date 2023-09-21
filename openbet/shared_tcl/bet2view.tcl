# $Id: bet2view.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
# (C) 2005 Orbis Technology Ltd. All rights reserved.
#
# Bet-2-View
#
# Procedures:
#    OB_Bet2View::init              one time initialisation
#    OB_Bet2View::check_qualify     check Bet2View qualification for customer
#    OB_Bet2View::insert_b2v_msg    insert a msg to be sent to be sent to RP
#

# Namespace Variables
#
namespace eval OB_Bet2View {
	variable INIT 0
	variable CFG
}

#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One-time initialisation
#
proc OB_Bet2View::init args {

	variable INIT
	variable CFG

	if {$INIT} {
		return
	}

	OT_LogWrite 15 {OB_Bet2View::init}

	set CFG(ruk_send_details_at_bet_placement) [OT_CfgGet RUK_SEND_DETAILS_AT_BET_PLACEMENT "FALSE"]
	set CFG(racing_uk_min_stake) [OT_CfgGet RACING_UK_MIN_STAKE 5]
	set CFG(check_for_streaming_video_qualification) [OT_CfgGet CHECK_FOR_STREAMING_VIDEO_QUALIFICATION 1]

	# possible values: total_bet_on_each_event events_grouped_by_bet
	set CFG(ruk_qualifying_bet_logic) [OT_CfgGet RUK_QUALIFYING_BET_LOGIC events_grouped_by_bet]

	set min_bet_amount_list [OT_CfgGet RUK_MIN_BET_AMOUNT {GBP 5.00}]
	foreach {ccy_code amount} $min_bet_amount_list {
		set CFG(ruk_min_bet_amount,$ccy_code) $amount
	}

	OB_Bet2View::prepare_queries

	set INIT 1
}



#--------------------------------------------------------------------------
# Prepare queries
#--------------------------------------------------------------------------
proc OB_Bet2View::prepare_queries {} {

	OT_LogWrite 15 {OB_Bet2View::prepare_queries}

	db_store_qry qualify_bet2view {
		execute procedure pInsStrVidBet
		(
			p_cust_id = ?,
			p_bet_id = ?,
			p_ev_id = ?,
			p_status = ?,
			p_rp_cust_id = ?
		)
	}

	db_store_qry send_oxi_push_msg {
		execute procedure pInsOxiPushMsg
		(
			p_app_id = ?,
			p_base_id = ?
		)
	}

	db_store_qry get_bet2view_app_id {
		select
			app_id
		from
			toxipushapp
		where
			name = "BET2VIEW"
	}

	ob_db::store_qry ins_streaming_video {
		insert
			into
		tVSCust
			(cust_id, ev_id, bet_id, status, video_provider_id)
		values
			(?,?,?,?,?)
	}

	ob_db::store_qry get_events_with_sv_qualifying_bet {
		select
			ev_id
		from
			tVSCust
		where
			cust_id = ? and
			ev_id in (?,?,?,?,?,?,?,?,?,?)
	}

	ob_db::store_qry get_vs_provider_id {
		select
			video_provider_id
		from
			tVideoProvider
		where
			video_provider = ?
	} 3600

	ob_db::store_qry get_customer_total_bet_amount_on_single_event {
		select {+ORDERED}
			nvl(sum(b.stake/b.num_selns),0) as total_bet_on_event
		from
			tbet  b,
			tobet o,
			tevoc s
		where
			b.acct_id  = ?
		and b.cr_date >= (select cr_date from tev where ev_id = ?)
		and b.bet_id   = o.bet_id
		and o.ev_oc_id = s.ev_oc_id
		and s.ev_id = ?
	}

	ob_db::store_qry get_ev_ids_for_bet_id_qry {
		select
			eo.ev_id
		from
			tBet b,
			tOBet o,
			tEvOc eo,
			tEv e
		where
			b.bet_id = ?
		and b.bet_id = o.bet_id
		and o.ev_oc_id = eo.ev_oc_id
		and eo.ev_id = e.ev_id
		order by
			e.start_time asc;
	}
}



# Check if customer qualifies to a view a race based on the following critera:
#
# bet_type   - tBet.bet_type
# sk         - index that relates to a specific bet within BSEL
# rp_cust_id - optional, a customer id used by racing post to track customers,
#              populated by remote betslip only
#
# 1) Event-type flag & event flag must include the RP flag (Racing Post)
# 2) Stake is greater or equal to the specified qualify amount as defined
#    by config item RACING_UK_MIN_STAKE (default 5 GBP)
#
# If all of the criteria above is satisfied, an entry is made into tstreamingvideo

# A msg is sent via the OXI push server instantly for RP-afilliated customers who have
# placed a bet using the remote betslip.
# Otherwise, a msg is sent when the customer views on a race using the tv viewer
#
proc OB_Bet2View::check_qualify {bet_type sk {rp_cust_id ""}} {

	global CUST BSEL
	variable CFG

	OT_LogWrite 1 "==> do_qualify_bet2view (bet_type $bet_type) (sk:$sk) \
	                                     (rp_cust_id:$rp_cust_id)"

	set min_qualify_stake_gbp $CFG(racing_uk_min_stake)

	# Get the bet no
	for {set i 0} {$i < $BSEL($sk,num_bets_avail)} {incr i} {
		if {$bet_type == $BSEL($sk,bets,$i,bet_type)} {
			set bet_no $i
			break
		}
	}

	set b "$sk,bets,$bet_no"

	set cust_id     $CUST(cust_id)
	set bet_id      $BSEL($b,bet_id)
	set bet_placed  $BSEL($b,bet_placed)
	set total_stake $BSEL($b,stake)

	# Check if total_stake / num_selns is greater than the minimum qualifying amount
	# Support Call #00018062 - currencies conversion problems
	# Qualifying amount is 5GBP converted to user's currency eg 7.31 euro
	# When we convert 7.31 back to Euro here we get 4.99 GBP
	# which is not enough to qualify. Round it up here.

	set TINY "1e-9"
	set stake_per_seln  [expr {floor(($total_stake * 100) / ($CUST(exch_rate) * $BSEL($sk,num_selns)) + $TINY) / 100}]
	set stake_per_seln [format %2f $stake_per_seln]

	# Check if Bet qualifies
	if {$stake_per_seln < $min_qualify_stake_gbp} {
		OT_LogWrite 1 "Bet below min. threshold $min_qualify_stake_gbp -> \
		               Stake per seln (num_selns: $BSEL($sk,num_selns)): $stake_per_seln"
		return
	}

	if {$bet_placed} {

		for {set l 0} {$l < $BSEL($sk,num_legs)} {incr l} {

			# no need to check part nos as part nos
			# are associated with the same event
			set ev_id      $BSEL($sk,$l,0,ev_id)
			set type_flags $BSEL($sk,$l,0,type_flags)
			set ev_flags   $BSEL($sk,$l,0,ev_flags)

			if {[string first "RP" $type_flags] != -1 &
			    [string first "RP" $ev_flags] != -1} {

				OT_LogWrite 1 "Bet(bet_id:$bet_id) qualified for RP event (ev_id:$ev_id)"

				# Customer has qualified, set status to Q
				set status "Q"

				# This won't be stored unless the FUNC_TV_VIEWER cfg item is set but
				# neither should this proc.
				if {[catch {set rs [db_exec_qry qualify_bet2view \
			                                        $cust_id\
			                                        $bet_id\
			                                        $ev_id\
			                                        $status\
			                                        $rp_cust_id]} msg]} {
					OT_LogWrite 1 "Error : Failed to execute query qualify_bet2view : $msg"
					return
				}

				set nrows [db_get_nrows $rs]

				if {$nrows == 0} {
					# Weird this shouldn't happen...... log it
					OT_LogWrite 1 "qualify_bet2view:0 rows returned expected 1"
					OT_LogWrite 1 "Failed to run qualify_bet2view with args:\
							$cust_id $bet_id $ev_id"
					return
				}
				set video_id [db_get_coln $rs 0 0]
				db_close $rs

				# Using Perform streaming video will not send message to
				# oxi push.
				if { [OT_CfgGet USE_PERFORM_HORSE_RACING_VIDEO 1] == 1 } {
					if {$video_id == 0} {
						# If it returns 0 then it didn't insert the row, NOT GOOD! log it
						OT_LogWrite 1 "Failed to run qualify_bet2view with args:\
							$cust_id $bet_id $ev_id"
					} else {
	
						# Send all RP-affiliated remote bets qualifying bets
						# to RP via Oxi Push instantly
						if {$rp_cust_id != ""} {
	
							OT_LogWrite 1 " Remote betslip RP-affiliated customer:\
										send to RP immediately"
	
							set msg_result [OB_Bet2View::insert_b2v_msg $video_id]
	
							if {[lindex $msg_result 0]} {
								# Success
								set msg_id [lindex $msg_result 1]
								OT_LogWrite 1 "Inserted msg for oxi push $msg_id"
							} else {
								# Failed
								OT_LogWrite 1 "Failed to insert msg for oxi push"
							}
						}
						## end of Oxi push msg stuff.
					}
				}
			}
		}
		OT_LogWrite 1 "<== do_qualify_bet2view"
	}
}



# Inserts a msg to be sent via the OXI push server to Racing Post
#
# Input
#
# video_id - the pk of tStreamingVideo.video_id indicating the bet that
#                  qualified to view the race
# Output
#   <result msg_id> - a list format for the appropriate responses as follows:
#
#          Success - <1 4>
#          Failure - <0 {}>
#
proc OB_Bet2View::insert_b2v_msg {video_id} {

	if [catch {set rs [db_exec_qry get_bet2view_app_id]} msg] {
		OT_LogWrite 1 "ERROR: failed to exec bet2view query on event: $msg"
		return [list 0 {}]
	}

	set nrows [db_get_nrows $rs]

	if {$nrows!=1} {
		OT_LogWrite 1 "get_bet2view_app_id:$nrows rows returned expected 1"
		return [list 0 {}]
	}

	set app_id [db_get_coln $rs 0 0]

	db_close $rs

	if [catch {set rs [db_exec_qry send_oxi_push_msg $app_id $video_id]} msg] {
		OT_LogWrite 1 "Error with send_oxi_push_msg query with app_id: $app_id and video_id:$video_id :$msg"
		return [list 0 {}]
	}

	set nrows [db_get_nrows $rs]

	if {$nrows == 0} {
		# Weird this shouldn't happen...... log it
		OT_LogWrite 1 "send_oxi_push_msg:0 rows returned expected 1"
		OT_LogWrite 1 "Failed to run send_oxi_push_msg"
		return [list 0 {}]
	} else {
		set msg_id [db_get_coln $rs 0 0]

		if {$msg_id == 0} {
			# If it returns 0 then it didn't insert the row, NOT GOOD! log it
			OT_LogWrite 1 "Failed to run send_oxi_push_msg"
			return [list 0 {}]
		}

		db_close $rs

		# If its all going well then it returns the primary key
		return [list 1 $msg_id]
	}
}



# Check if customer qualifies to a view a race or not.
# Works for both RUK and ATR
# Uses bet packages
#
#   bets    - The list of all bets that were placed i.e. bet_placed is Y
#
#   returns -
#
proc OB_Bet2View::check_qualify_bet_pkg {bets} {

	variable CFG

	ob_log::write DEBUG {OB_Bet2View::check_qualify_bet_pkg: bets=$bets}

	if {!$CFG(check_for_streaming_video_qualification) || [llength $bets] < 1} {
		return
	}

	set cust_id [ob_login::get cust_id]
	set acct_id [ob_login::get acct_id]
	set ccy_code [ob_login::get ccy_code]

	# bail if we do not know anything about the customer's ccy-code
	if {![info exists CFG(ruk_min_bet_amount,$ccy_code)]} {
		ob_log::write WARNING {OB_vs_qualify::check_qualify_bet_pkg: unknown currency - $ccy_code}
		return
	}

	# List of relevant Video Provider events we've just bet on
	set evs [list]
	set bet_id_list [list]

	# for each bet the customer has just made - check
	# if its associated event has a video provider video feed
	foreach bet_num $bets {

		set total_stake [lindex [ob_bet::get_bet $bet_num stake] 1]
		set group_id [lindex [ob_bet::get_bet $bet_num group_id] 1]
		set num_selns [lindex [ob_bet::get_group $group_id num_selns] 1]
		set bet_id [lindex [ob_bet::get_bet $bet_num bet_id] 1]
		lappend bet_id_list $bet_id

		# Populate array of event ids grouped by bet. This array is used later
		# when checking for bet qualification.
		if {$CFG(ruk_qualifying_bet_logic) == {events_grouped_by_bet}} {

			# We require event ids to be sorted by event starting time in
			# ascending order, so customers will qualify to view the earliest
			# events. So, don't pick the event id from the selection; use
			# a separate query, instead.
			if {[catch {
				set _rs [ob_db::exec_qry get_ev_ids_for_bet_id_qry $bet_id]
			} msg]} {
				ob_log::write ERROR {The query get_ev_ids_for_bet_id_qry has thrown an exception - $msg}
				return
			}

			set nrows [db_get_nrows $_rs]

			for {set r 0} {$r < $nrows} {incr r} {
				set _ev_id [db_get_col $_rs $r ev_id]
				if {[info exists ev_ids_grouped_by_bet_id($bet_id)]} {
					if {[lsearch $ev_ids_grouped_by_bet_id($bet_id) $_ev_id] == -1} {
						lappend ev_ids_grouped_by_bet_id($bet_id) $_ev_id
					}
				} else {
					set ev_ids_grouped_by_bet_id($bet_id) [list $_ev_id]
					set ev_ids_grouped_by_bet_id($bet_id,total_stake) $total_stake
				}
			}

			ob_db::rs_close $_rs
		}

		foreach leg_num [lindex [ob_bet::get_group $group_id legs] 1] {

			set selns [lindex [ob_bet::get_leg $leg_num selns] 1]

			# no need to check part nos as part nos
			# are associated with the same event
			set ev_id [lindex [ob_bet::get_oc [lindex $selns 0]  ev_id] 1]
			set type_flags [lindex [ob_bet::get_oc [lindex $selns 0] type_flags] 1]
			set ev_type_flags [lindex [ob_bet::get_oc [lindex $selns 0] ev_type_flags] 1]
			set ev_flags [lindex [ob_bet::get_oc [lindex $selns 0] ev_flags] 1]

			ob_log::write DEBUG {~*~*~*~ ev_id         = $ev_id ~*~*~*~*~~}
			ob_log::write DEBUG {~*~*~*~ ev_type_flags = $ev_type_flags ~*~*~*~*~~}
			ob_log::write DEBUG {~*~*~*~ type_flags    = $type_flags ~*~*~*~*~~}
			ob_log::write DEBUG {~*~*~*~ ev_flags      = $ev_flags ~*~*~*~*~~}
			ob_log::write DEBUG {~*~*~*~ selns         = $num_selns ~*~*~*~*~~}

			ob_log::write INFO {Found ev_type_flags $ev_type_flags for ev_oc_id [lindex $selns 0]}

			# The video provider, as defined in tVideoProvider.video_provider
			set vp {}

			# RVA: Racing Post Video Available
			if {[string match *RVA* $ev_type_flags]} {
				set vp RP
			# AVA: At The Races (ATR) Video Available
			} elseif {[string match *AVA* $ev_type_flags]} {
				set vp ATR
			}

			if {$vp != {}} {

				# Get hold of the video provider id (tVideoProvider.video_provider_id)

				if {[catch {
					set rs [ob_db::exec_qry get_vs_provider_id $vp]} msg]
				} {
					ob_log::write ERROR {The query get_vs_provider_id has thrown an exception - $msg}
					return
				}

				if {[db_get_nrows $rs] == 0} {
					ob_log::write ERROR {ERROR - Video Provider $vp was not found in the tvideoprovider table}
					ob_db::rs_close $rs
					return
				}

				set vp_id [db_get_col $rs 0 video_provider_id]
				ob_db::rs_close $rs

				if {[lsearch $evs $ev_id] == -1} {

					lappend evs $ev_id

					# Don't care which bet_id we use, we just need
					# a reference to one of them
					set bet_id_for_event($ev_id)       $bet_id
					set bet_id_for_event($ev_id,vp)    $vp
					set bet_id_for_event($ev_id,vp_id) $vp_id
				}
			}
		}
	}

	if {[info exists bet_id_for_event]} {
		ob_log::write_array INFO bet_id_for_event
	}

	if {[llength $evs] == 0} {
		#there are no ruk events in this selection
		return
	}

	#need to check if this customer has already
	#made a qualifying bet for any of these events.

	set MAX 10

	set total [expr {(([llength $evs]-1) / $MAX) + 1}]

	for {set i 0} {$i < $total} {incr i} {

		set qry_evs [list]

		for {set j 0} {$j < $MAX} {incr j} {

			set k [expr {($i * $MAX) + $j}]

			if {$k < [llength $evs]} {
				lappend qry_evs [lindex $evs $k]
			} else {
				lappend qry_evs -1
			}
		}

		if {[catch {
			set rs [eval ob_db::exec_qry get_events_with_sv_qualifying_bet $cust_id $qry_evs]
		} msg]} {
			ob_log::write ERROR {Query get_events_with_sv_qualifying_bet has thrown an exception - cust_id $cust_id - $msg}
			return
		}

		set nrows [db_get_nrows $rs]

		for {set r 0} {$r < $nrows} {incr r} {

			set ev_id [db_get_col $rs $r ev_id]

			if {![info exists qualified($ev_id)] } {
				set qualified($ev_id) 1
			}
		}

		ob_db::rs_close $rs
	}

	if {$CFG(ruk_qualifying_bet_logic) == {total_bet_on_each_event}} {

		# get the total bet on each event to check if a qualifying bet record needs to be stored
		foreach ev_id $evs {

			if {[catch {
				set rs [ob_db::exec_qry get_customer_total_bet_amount_on_single_event $acct_id $ev_id $ev_id]
			} msg]} {
				ob_log::write ERROR {get_customer_total_bet_amount_on_single_event has thrown an exception - cust_id $cust_id - $msg}
				return
			}

			set nrows [db_get_nrows $rs]
			if {$nrows != 1} {
				ob_log::write ERROR {get_customer_total_bet_amount_on_single_event returned $nrows rows}
				ob_db::rs_close $rs
				continue
			}

			set total_bet_on_event [db_get_col $rs 0 total_bet_on_event]

			if {![info exists qualified($ev_id)] && $total_bet_on_event >= $CFG(ruk_min_bet_amount,$ccy_code)} {

				set status Q

				if {$CFG(ruk_send_details_at_bet_placement) == "TRUE"} {
					set status P
				}

				# Do the insert into the tStreamingVideo table
				if {[catch {
					ob_db::exec_qry ins_streaming_video $cust_id $ev_id $bet_id_for_event($ev_id) $status $bet_id_for_event($ev_id,vp_id)
				} msg]} {
					ob_log::write ERROR {ins_streaming_video has thrown an exception - customer($cust_id) - $msg}
					break
				}
			}

			ob_db::rs_close $rs
		}

	} elseif {$CFG(ruk_qualifying_bet_logic) == {events_grouped_by_bet}} {

		foreach _bet_id $bet_id_list {

			# The amount needed to view video streams. If this gets greater
			# than total bet stake, then customer can't qualify to view any
			# more streams.
			set stream_credit 0.00

			foreach _ev_id $ev_ids_grouped_by_bet_id($_bet_id) {

				# If customer has not already made a qualifying bet on the
				# current event...
				if {![info exists qualified($_ev_id)]} {

					set stream_credit [expr {$stream_credit + $CFG(ruk_min_bet_amount,$ccy_code)}]

					if {$ev_ids_grouped_by_bet_id($_bet_id,total_stake) >= $stream_credit} {

						set status Q

						if {$CFG(ruk_send_details_at_bet_placement) == {TRUE} && $bet_id_for_event($_ev_id,vp) == {RP}} {
							set status P
						}

						# Do the insert into the tVSCust table
						if {[catch {
							set _rs [ob_db::exec_qry ins_streaming_video $cust_id $_ev_id $_bet_id $status $bet_id_for_event($_ev_id,vp_id)]
						} msg]} {
							ob_log::write ERROR {ins_streaming_video has thrown an exception - customer($cust_id) - $msg}
							break
						}

						## Oxi push msg stuff

						set video_id [ob_db::get_serial_number ins_streaming_video]
						db_close $_rs

						# Using Perform streaming video will not send message to
						# oxi push.
						if { [OT_CfgGet USE_PERFORM_HORSE_RACING_VIDEO 1] == 1 } {
							if {$video_id == 0 || $video_id == {}} {
								# If it returns 0 then it didn't insert the row, NOT GOOD! log it
								ob_log::write ERROR \
									{Failed to run ins_streaming_video with args: $cust_id $_ev_id $_bet_id $status $vid_prov_id}
								break
							} else {
								# Racing UK only
								if {$bet_id_for_event($_ev_id,vp) == {RP}} {
									set msg_result [OB_Bet2View::insert_b2v_msg $video_id]
									if {[lindex $msg_result 0]} {
										# Success
										set msg_id [lindex $msg_result 1]
										ob_log::write INFO {Inserted msg for oxi push $msg_id}
									} else {
										# Failed
										ob_log::write ERROR {Failed to insert msg for oxi push}
									}
								}
							}
						}

						set qualified($_ev_id) 1

					} else {
						break
					}
				}
			}
		}
	}
}
