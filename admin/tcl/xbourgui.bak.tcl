	global DB BET POOL_BET

	# Get which type of query has been selected
	set query_type [reqGetArg QueryType]

	if {[OT_CfgGet VALIDATE_BET_SEARCHES 0]} {
		# Validate filters to make sure that compulsory fields are present,
		# to ensure that we don't run nasty queries.

		set compulsory_fields ""

		# Note that although TSN is only relevant for pools bets and ShopNumber
		# for sports bets, we can include these in all the different bet
		# searches handled, as if they're empty they won't affect validation.
		foreach {a b} {
			username      Customer
			cust_id       CustId
			lname         LName
			email         Email
			acct_no       AcctNo
			rep_code      RepCode
			bet_date_1    BetDate1
			bet_date_2    BetDate2
			receipt       Receipt
			shop_no       ShopNumber
			tsn           TSN
		} {
			set $a [reqGetArg $b]
			append compulsory_fields [subst "$$a"]
		}


		# We do this seperately as the N/A date_value is actually 0
		set bdperiod [reqGetArg BetPlacedFrom]

		# Go back to the bet search page if we have no compulsory fields
		if {$compulsory_fields == "" && ($bdperiod == 0 || $bdperiod == "")} {
			# Rebind request args
			for {set n 0} {$n < [reqGetNumVals]} {incr n} {
				tpBindString [reqGetNthName $n] [reqGetNthVal $n]
			}
			err_bind "There aren't sufficient filters on the bet query.
				Please enter a new search."
			ADMIN::BET::go_bet_query
			return
		}
	} else {
		# Just get the values from the request as we need them later on
		foreach {a b} {
			username      Customer
			lname         LName
			email         Email
			acct_no       AcctNo
			rep_code      RepCode
			bet_date_1    BetDate1
			bet_date_2    BetDate2
			receipt       Receipt
			shop_no       ShopNumber
			tsn           TSN
			bdperiod      BetPlacedFrom
		} {
			set $a [reqGetArg $b]
		}
	}

	# Grab any (optional) args
	foreach {n v} $args {
		set $n $v
	}

	# query_type could still be empty at this point, but this all
	# fails to work if it is (the Bet Type select fails to populate, the little sod).
	# so default to something reasonable
	# we should probably be providing some kind of way of setting this from the form
	# and defaulting to something sensible, rather than hiding it away, since not setting
	# it properly causes us some problems
	if {$query_type == ""} {
		set query_type "sports"
	}

	#Get variable indicating whether to include canceled bets
	set cancel_bet [reqGetArg CancelBet]

	set where [list]

	set bad 0
	set criteria_found 0

	set xgame_bet_required 0;# must be set non-zero if tXGameBet is referenced

	#
	# Do not include or include cancelled bets
	#
	if {$query_type == "sports" && $cancel_bet == ""} {
		 lappend where "b.status = 'A'"
	}


	#
	# Customer fields
	#
	if {[info exists specific_cust_id]} {
		lappend where "c.cust_id = $specific_cust_id"
	} elseif {[regexp {^0*([0-9]+)$} [reqGetArg CustId] all id]} {
			lappend where "c.cust_id = $id"
	}
	if {[string length [set name $username]] > 0} {

		if {[reqGetArg LBOSearch] == "Y"} {
			# Shop account usernames are all preceded by 1 space
			set name " [string trimleft $name]"
		}

		if {[reqGetArg UpperCust] == "Y"} {
			lappend where "c.username_uc like [upper_q '${name}%']"
		} else {
			lappend where "c.username like \"${name}%\""
		}
	}
	if {[string length [set fname [reqGetArg FName]]] > 0} {
		lappend where "[upper_q r.fname] = [upper_q \'$fname\']"
	}
	if {[string length $lname] > 0} {
		lappend where [get_indexed_sql_query $lname lname]
	}
	if {[string length $email] > 0} {
		lappend where [get_indexed_sql_query "%$email" email]
	}
		if {[string length [set elitecust [string trim [reqGetArg EliteSearch]]]] > 0} {
				lappend where "c.elite = 'Y'"
		}

	if {[string length $acct_no] > 0} {
		if {[string equal $acct_no [string toupper $acct_no]]} {
			lappend where "c.acct_no = '$acct_no'"
		} else {
			lappend where "upper(c.acct_no) = upper('$acct_no')"
		}
	}

	set additional_tables ""

	if {[string length $shop_no] > 0} {
		set additional_tables [concat $additional_tables ", tRetailShop rs"]
		lappend where "rs.shop_id = r.shop_id"
		if {[string length [reqGetArg full_shop_no]] > 0} {
			lappend where "rs.shop_no = '${shop_no}'"
		} else {
			lappend where "rs.shop_no like '${shop_no}%'"
		}
	}

	if {[reqGetArg LBOSearch] == "Y"} {
		lappend where "a.owner = 'F'"
		lappend where "a.owner_type in ('STR','VAR','OCC','REG','LOG')"
	}

	#
	# If we have active shop fielding accounts we need to lookup the notification/referrals
	#
	set shop_select ""
	if {[OT_CfgGet FUNC_SHOP_FIELDING_ACCOUNTS 0]} {
		set shop_select ",
			case when a.owner = 'F'
			     and a.owner_type in ('LOG','REG','OCC','VAR','STR')
			then 1 else 0 end is_shop_fielding_bet,
			case when a.owner = 'F'
			     and a.owner_type in ('LOG','REG','OCC','VAR','STR')
			     and exists (
				select ref_id
				from toverride
				where toverride.ref_id=b.bet_id and
				toverride.ref_key = 'BET' and
				toverride.action = 'ShopBetOverride'
			) then 1 else 0 end is_referral"
	}

	#
	# Sort by Sub or Bet?
	#

	if {$query_type == "xgame"} {
		set sort_sub [reqGetArg UseSub]
	}

	#
	# Receipt: different things for sports bet/game bet
	#
	set receipt [string toupper [reqGetArg Receipt]]

	if {[string length $receipt] > 0} {

		if {$query_type == "sports"} {

			set inet_rxp {O/([0-9]+)/([0-9]+)}
			set bet_rxp  {^#([0-9]+)$}

			if {[regexp $inet_rxp $receipt all cust count]} {
				lappend where "c.cust_id = $cust"
				lappend where "b.receipt like '${receipt}%'"
			} elseif {[regexp $bet_rxp $receipt all bet_id]} {
				lappend where "b.bet_id = $bet_id"
			} else {
				lappend where "b.receipt like '${receipt}%'"
			}

		} elseif {$query_type == "pools"} {

			set inet_rxp {P/([0-9]+)/([0-9]+)}
			set bet_rxp  {^#([0-9]+)$}

			if {[regexp $inet_rxp $receipt all cust count]} {
				lappend where "c.cust_id = $cust"
				lappend where "b.receipt like '${receipt}%'"
			} elseif {[regexp $bet_rxp $receipt all bet_id]} {
				lappend where "b.pool_bet_id = $bet_id"
			} else {
				lappend where "b.receipt like '${receipt}%'"
			}

		} elseif {$query_type == "xgame"} {
			#
			# Sort by Sub or Bet?
			#

			set bet_rcpt $receipt

			set rcpt_elems [split $bet_rcpt "/"]

			if {[llength $rcpt_elems] == 3} {
				set sub_id [lindex $rcpt_elems 2]

				if {$sort_sub == "Sub"} {
					lappend where "s.xgame_sub_id = $sub_id"
				}
			}
		}
	}
	# Tote TSN number
	if {$tsn != ""} {
		lappend where "exists (
			select
				1
			from
				tToteTSN
			where
				tToteTSN.pool_bet_id	= b.pool_bet_id
			and	tToteTSN.tsn			= '$tsn'
		)"
	}

	#
	# Bet date fields:
	#
	if {([string length $bet_date_1] > 0) || ([string length $bet_date_2] > 0)} {

		if {$query_type == "sports" || $query_type == "pools" || $query_type == "birfail"} {

			lappend where [mk_between_clause b.cr_date date $bet_date_1 $bet_date_2]
		} elseif {$query_type == "xgame"} {

			#If Xgames sort by Subscription/bet
			if {$sort_sub == "Sub"} {
				lappend where [mk_between_clause s.cr_date date $bet_date_1 $bet_date_2]
			} else {
				lappend where [mk_between_clause b.cr_date date $bet_date_1 $bet_date_2]
				set xgame_bet_required 1
			}
		}
	}

	#
	# Bet date fixed periods
	#
	if {[string length $bdperiod] > 0 && $bdperiod > 0} {

		if {$query_type == "sports" || $query_type == "pools" || $query_type == "birfail"} {
			set qcol b.cr_date
		} elseif {$query_type == "xgame"} {
			if {$sort_sub == "Sub"} {
				set qcol s.cr_date
			} else {
				set qcol b.cr_date
				set xgame_bet_required 1
			}
		}

		# no custom date specified so parse date dropdown
		if {([string length $bet_date_1] == 0) && ([string length $bet_date_2] == 0)} {

			set now [clock seconds]

			switch -exact -- $bdperiod {
				1 {
					# Last hour
					set hour [expr {$now-60*60}]
					set lo [clock format $hour -format {%Y-%m-%d %H:%M:%S}]
					set hi [clock format $now -format {%Y-%m-%d %H:%M:%S}]
				}
				2 {
					# today
					set lo [clock format $now -format {%Y-%m-%d 00:00:00}]
					set hi [clock format $now -format {%Y-%m-%d 23:59:59}]
				}
				3 {
					# yesterday
					set yday [expr {$now-60*60*24}]
					set lo   [clock format $yday -format {%Y-%m-%d 00:00:00}]
					set hi   [clock format $yday -format {%Y-%m-%d 23:59:59}]
				}
				4 {
					# last 3 days
					set 3day [expr {$now-3*60*60*24}]
					set lo   [clock format $3day -format {%Y-%m-%d 00:00:00}]
					set hi   [clock format $now -format {%Y-%m-%d %H:%M:%S}]
				}
				5 {
					# last 7 days
					set 7day [expr {$now-7*60*60*24}]
					set lo   [clock format $7day -format {%Y-%m-%d 00:00:00}]
					set hi   [clock format $now -format {%Y-%m-%d %H:%M:%S}]
				}
				6 {
					# This month
					set lo [clock format $now -format {%Y-%m-01 00:00:00}]
					set hi [clock format $now -format {%Y-%m-%d %H:%M:%S}]
				}
				default {
					set lo [set hi ""]
				}
			}

			if {$lo != ""} {
				lappend where [mk_between_clause $qcol date $lo $hi]
			}
		}
	}

	#
	# Bet stake
	#
	set s1 [reqGetArg Stake1]
	set s2 [reqGetArg Stake2]

	if {([string length $s1] > 0) || ([string length $s2] > 0)} {
		lappend where [mk_between_clause b.stake number $s1 $s2]
		set xgame_bet_required 1
	}

	#
	# U stake
	#
	set s1 [reqGetArg UStake1]
	set s2 [reqGetArg UStake2]

	if {([string length $s1] > 0) || ([string length $s2] > 0)} {
		lappend where [mk_between_clause "(b.stake / b.num_lines)" number $s1 $s2]
		set xgame_bet_required 1
	}

	#
	# Settlement date
	#
	set sd1 [reqGetArg StlDate1]
	set sd2 [reqGetArg StlDate2]

	if {([string length $sd1] > 0) || ([string length $sd2] > 0)} {
		if {$query_type == "sports"} {
			lappend where [mk_between_clause ss.settled_at date $sd1 $sd2]
			lappend where "b.bet_id = ss.bet_id"
			set additional_tables [concat $additional_tables ", tBetStl ss"]
		} elseif {$query_type == "pools"} {
			lappend where [mk_between_clause ss.settled_at date $sd1 $sd2]
			lappend where "b.pool_bet_id = ss.pool_bet_id"
			set additional_tables [concat $additional_tables ", tPoolBetStl ss"]
		} elseif {$query_type == "xgame"} {
			if {$sort_sub != "Sub"} {
				lappend where [mk_between_clause b.settled_at date $sd1 $sd2]
				set xgame_bet_required 1
		  	}
		}
	}

	#
	# Winnings
	#
	set w1 [reqGetArg Wins1]
	set w2 [reqGetArg Wins2]

	if {([string length $w1] > 0) || ([string length $w2] > 0)} {
		lappend where [mk_between_clause b.winnings number $w1 $w2]
		set xgame_bet_required 1
	}

	# see if the bet has some winnings, this could be adapted to do
	# refunds as well
	set w3 [reqGetArg HasWinnings]
	if {[string is integer -strict $w3] && $w3} {
		lappend where "b.winnings > 0"
	}

	#
	# Channels:
	#
	if {([string length [set op [reqGetArg ChannelOp]]] > 0) &&
		([set numchannels [reqGetNumArgs ChannelName]] > 0)} {

		for {set n 0} {$n < $numchannels} {incr n} {
			lappend chan_list  [reqGetNthArg ChannelName $n]
		}

		if {$op == "0"} {
			set qop "not in "
		} else {
			set qop "in "
		}

		if {$query_type == "sports" || $query_type == "pools" || $query_type == "birfail"} {
			lappend where "b.source $qop ('[join $chan_list ',']')"
		} elseif {$query_type == "xgame"} {
			lappend where "s.source $qop ('[join $chan_list ',']')"
		}
	}

	# On Course betting flags assigned to the bet slip.
	# These will not be passed if ON_COURSE_BETTING is disabled.
	set numOnCourseType [reqGetNumArgs CourseType]
	set OnCourseOp [reqGetArg OnCourseOp]

	set include_hedged 0
	set include_field  0

	if {$numOnCourseType > 0 && [string length $OnCourseOp] > 0} {

		for {set n 0} {$n < $numOnCourseType} {incr n} {
			set course_type_arg [reqGetNthArg CourseType $n]

			#
			# If hedging, we want to join onto tHedgedBet and check there,
			# otherwise we need to join onto tOnCourseRepBet (as fielded
			# bet).  Could have both.
			#
			if {$course_type_arg == "H"} {
				set include_hedged 1
			} else {
				set include_field  1
				lappend OnCourseType_list  $course_type_arg
			}
		}

		#
		# Note that we don't handle the case for X|0|0, as if we have this we
		# won't have reached this point, and if we somehow did we don't want
		# to do anything anyway.
		#
		if {$OnCourseOp} {
			set bet_id_op "in"
		} else {
			set bet_id_op "not in"
		}

		switch -exact -- "${include_hedged}|${include_field}" {
			"0|1" {
				lappend where "b.bet_id $bet_id_op (
					select ocb2.bet_id
					from tOnCourseRepBet ocb2
					where ocb2.on_course_type in ('[join $OnCourseType_list ',']')
				)"
			}
			"1|0" {
				lappend where "b.bet_id $bet_id_op (
					select hb2.bet_id
					from tHedgedBet hb2
				)"
			}
			"1|1" {
				lappend where "b.bet_id $bet_id_op (
					select hb.bet_id
					from tHedgedBet hb
					union
					select ocb.bet_id
					from tOnCourseRepBet ocb
					where ocb.on_course_type in ('[join $OnCourseType_list ',']')
				)"
			}
		}
	}


	#
	# Rep Code
	#
	# We can optimise this depending on whether or not we're already joining
	# onto tHedgedBet or tOnCourseRepBet, which will only be the case if the
	# user's selected stuff in the CourseType selection box (see above), so
	# we can re-use the variables (include_hedged and include_field) from there
	#
	if {$rep_code != ""} {

		if {$include_hedged && !$include_field} {

			# Just filtering hedged bets
			lappend where "b.bet_id in (
				select hb2.bet_id
				from thedgedbet hb2, toncourserep ocr2
				where ocr2.rep_code_id = hb2.rep_code_id and ocr2.rep_code = '$rep_code'
			)"

		} elseif {!$include_hedged && $include_field} {

			# Just filtering fielded bets
			lappend where "b.bet_id in (
				select ocb2.bet_id
				from toncourserepbet ocb2, toncourserep ocr2
				where ocr2.rep_code_id = ocb2.rep_code_id and ocr2.rep_code = '$rep_code'
			)"

		} else {

			# Filtering both hedged and fielded bets
			lappend where "b.bet_id in (
				select hb2.bet_id
				from thedgedbet hb2, toncourserep ocr2
				where ocr2.rep_code_id = hb2.rep_code_id and ocr2.rep_code = '$rep_code'
				union
				select ocb2.bet_id
				from toncourserepbet ocb2, toncourserep ocr2
				where ocr2.rep_code_id = ocb2.rep_code_id and ocr2.rep_code = '$rep_code'
			)"
		}
	}


	#
	# Bet type:
	#
	if {([string length [set op [reqGetArg BetTypeOp]]] > 0) &&
		([set nt [reqGetNumArgs BetType]] > 0)} {

		for {set n 0} {$n < $nt} {incr n} {
			lappend bt [reqGetNthArg BetType $n]
		}
		if {$op == "0"} {
			set qop "not in"
		} else {
			set qop "in"
		}

		if {$query_type == "sports" || $query_type == "birfail"} {
			lappend where "b.bet_type $qop ('[join $bt ',']')"
		} elseif {$query_type == "xgame"} {
			lappend where "d.sort $qop ('[join $bt ',']')"
		}
	}

	#
	# Pools types:
	#
	if {([string length [set op [reqGetArg PoolTypeOp]]] > 0) &&
		([set nt [reqGetNumArgs PoolType]] > 0)} {

		for {set n 0} {$n < $nt} {incr n} {
			lappend pt [reqGetNthArg PoolType $n]
		}
		if {$op == "0"} {
			set qop "not in"
		} else {
			set qop "in"
		}

		if {$query_type == "pools"} {
			lappend where "p.pool_type_id $qop ('[join $pt ',']')"
		}
	}

	#
	# Meetings:
	#
	set pt [list]
	if {([string length [set op [reqGetArg MeetingTypeOp]]] > 0) &&
		([set nt [reqGetNumArgs PoolMeeting]] > 0)} {

		for {set n 0} {$n < $nt} {incr n} {
			lappend pt [reqGetNthArg PoolMeeting $n]
		}
		if {$op == "0"} {
			set qop "not in"
		} else {
			set qop "in"
		}

		if {$query_type == "pools"} {
			lappend where "t.ev_type_id $qop ('[join $pt ',']')"
		}
	}

	#
	# If Xgame, Competition number field:
	#
	if {[string length [set compnum [reqGetArg CompNo]]] > 0} {
		regsub -all {[^0-9]} $compnum "" comp_no
		lappend where "g.comp_no = $comp_no"
	}

	#
	# Bet Settled
	#
	if {[string length [set settled [reqGetArg Settled]]] > 0} {
		if {$query_type == "sports" && $settled == "N"} {
			lappend where "a.acct_id = un.acct_id"
			lappend where "b.bet_id = un.bet_id"
			set additional_tables [concat $additional_tables ", tBetUnstl un"]
		} else {
			lappend where "b.settled = '$settled'"
			set xgame_bet_required 1
		}
	}

	#
	# Bet settle method
	#
	if {[string length [set settleHow [reqGetArg SettleHow]]] > 0} {
		if {$settleHow=="M"} {
			if {[OT_CfgGet OPENBET_CUST] == "LADBROKES"} {
				lappend where "b.settled_how = 'M'"
				set xgame_bet_required 1
			} else {
				lappend where "t.bet_settlement = 'Manual'"
			}
		} elseif {$settleHow=="S"} {
			if {[OT_CfgGet OPENBET_CUST] == "LADBROKES"} {
				lappend where "b.settled_how <> 'M'"
				set xgame_bet_required 1
			} else {
				lappend where "t.bet_settlement <> 'Manual'"
			}
		}

	}

	#
	# Bet Status (pools bets)
	#
	if {[string length [set betStatus [reqGetArg BetStatus]]] > 0} {
		lappend where "b.status = '$betStatus'"
		set xgame_bet_required 1
	}

	#
	# Event status
	#
	if {[string length [set evStatus [reqGetArg EvStatus]]] > 0} {
		if {$evStatus=="A"} {
			set where_status "and e.status='A'"
		} elseif {$evStatus=="S"} {
			set where_status "and e.status='S'"
		}
	} else {
		set where_status ""
	}

	#
	# Specific class requests
	#
	if {([string length [set evClass [reqGetArg EvClassId]]] > 0) &&
		([reqGetArg EvClassId] != "All")} {
			set where_class "and e.ev_class_id = '$evClass'"
	} else {
        set where_class ""
    }

	#
	# Antepost bet paid/unpaid
	#
	if {[string length [set antepost [reqGetArg Antepost]]] > 0} {
		lappend where "b.paid = '$antepost'"
		set xgame_bet_required 1
	}

	if {[OT_CfgGet BF_ACTIVE 0]} {
		#
		# Betfair Bets - handle 'Y' cases here, 'N' later on in binding up
		#
		lappend where "b.bet_id = pb.bet_id"
		lappend where "b.bet_id = bo.bet_id"

		if {[reqGetArg BFPassThru] == "Y"} {
			set additional_tables [concat $additional_tables ", tBFPassBet pb"]
		} else {
			set additional_tables [concat $additional_tables ", outer tBFPassBet pb"]
		}

		if {[reqGetArg BFRiskReduce] == "Y"} {
			set additional_tables [concat $additional_tables ", tBFOrder bo"]
		} else {
			set additional_tables [concat $additional_tables ", outer tBFOrder bo"]
		}

		set selection ",bo.bf_order_id,pb.bf_pass_bet_id"
	} else {
		set selection ""
	}

	#
	# Unvetted manual bet descriptions
	#
	set where_manual_bets ""
	if {[OT_CfgGet NO_UNVETTED_BET_DESCRIPTION 0] == 1 \
		  && [reqGetArg UnvettedManualBetDesc] == "Y"} {
		set where_manual_bets "and o.desc_1 is null"
	}

	#
	# Don't run a query with no search criteria...
	#
	if {![llength $where]} {
		# Nothing selected
		err_bind "Please enter some search criteria"
		go_bet_query $query_type
		return
	}

	set where     [concat and [join $where " and "]]

	# Only return the first n items from this search.
	set first_n ""
	if {[set n [OT_CfgGet SELECT_FIRST_N 0]]} {
	     set first_n " first $n "
	}
	# if sports bet chosen define sql
	if {$query_type == "sports"} {
		set sql [subst {
			select $first_n
				c.cust_id,
				c.elite,
				c.username,
				c.acct_no,
				a.ccy_code,
				b.ipaddr,
				b.cr_date,
				b.receipt,
				b.stake,
				b.status,
				b.settled,
				b.winnings,
				b.refund,
				b.num_lines,
				b.bet_type,
				b.leg_type,
				e.desc ev_name,
				m.name mkt_name,
				s.desc seln_name,
				s.result,
				s.ev_mkt_id,
				s.ev_oc_id,
				s.ev_id,
				o.bet_id,
				o.leg_no,
				o.part_no,
				o.leg_sort,
				o.price_type,
				NVL(o.no_combi,'') no_combi,
				o.banker,
				""||o.hcap_value hcap_value,
				""||o.o_num o_num,
				""||o.o_den o_den,
				hb.bet_id hedged_id,
				case when hb.bet_id is not null
					then "H"
					else ocb.on_course_type
				end as on_course_type,
				case when hb.bet_id is not null
					then ocrH.rep_code
					else ocrF.rep_code
				end as rep_code
				$shop_select
				$selection
			from
				tBet b,
				tBetType t,
				tOBet o,
				tAcct a,
				tCustomer c,
				tEvOc s,
				tEvMkt m,
				tEvOcGrp g,
				tEv e,
				tCustomerReg r,
				outer (tHedgedBet hb, tOnCourseRep ocrH),
				outer (tOnCourseRepBet ocb, tOnCourseRep ocrF)
				$additional_tables
			where
				b.bet_id = o.bet_id and
				b.bet_type = t.bet_type and
				b.acct_id = a.acct_id and
				a.cust_id = c.cust_id and
				r.cust_id = c.cust_id and
				o.ev_oc_id = s.ev_oc_id and
				s.ev_mkt_id = m.ev_mkt_id and
				m.ev_oc_grp_id = g.ev_oc_grp_id and
				s.ev_id = e.ev_id and
				a.owner    <> 'D' and
				b.bet_id = hb.bet_id and
				b.bet_id = ocb.bet_id and
				hb.rep_code_id = ocrH.rep_code_id and
				ocb.rep_code_id = ocrF.rep_code_id
				$where_status
				$where_class
				$where
			union
			select
				c.cust_id,
				c.elite,
				c.username,
				c.acct_no,
				a.ccy_code,
				b.ipaddr,
				b.cr_date,
				b.receipt,
				b.stake,
				b.status,
				b.settled,
				b.winnings,
				b.refund,
				b.num_lines,
				b.bet_type,
				b.leg_type,
				o.desc_1 ev_name,
				o.desc_2 mkt_name,
				o.desc_3 seln_name,
				'-' result,
				0 ev_mkt_id,
				0 ev_oc_id,
				0 ev_id,
				o.bet_id,
				1 leg_no,
				1 part_no,
				'--' leg_sort,
				'L' price_type,
				''  no_combi,
				'N' banker,
				'' hcap_value,
				'' o_num,
				'' o_den,
				hb.bet_id hedged_id,
				case when hb.bet_id is not null
					then "H"
					else ocb.on_course_type
				end as on_course_type,
				case when hb.bet_id is not null
					then ocrH.rep_code
					else ocrF.rep_code
				end as rep_code
				$shop_select
				$selection
			from
				tBet b,
				tManOBet o,
				tAcct a,
				tCustomer c,
				tCustomerReg r,
				outer tBetType t,
				outer (tHedgedBet hb, tOnCourseRep ocrH),
				outer (tOnCourseRepBet ocb, tOnCourseRep ocrF)
				$additional_tables
			where
				b.bet_id = o.bet_id and
				b.bet_type = t.bet_type and
				b.acct_id = a.acct_id and
				a.cust_id = c.cust_id and
				r.cust_id = c.cust_id and
				b.bet_type = 'MAN' and
				a.owner    <> 'D' and
				b.bet_id = hb.bet_id and
				b.bet_id = ocb.bet_id and
				hb.rep_code_id = ocrH.rep_code_id and
				ocb.rep_code_id = ocrF.rep_code_id
				$where
				$where_manual_bets
			order by 1 desc, 8, 25, 26

			}]

	# SQL for BIR bet fail
	} elseif {$query_type == "birfail"} {

		set sql [subst {
			select
				rr.failure_reason,
				b.bir_bet_id,
				c.cust_id,
				b.cr_date,
				b.bet_type,
				b.stake_per_line,
				b.placed_date,
				c.username,
				case
					when
						rr.failure_reason = 'OVERRIDES' and o.override <> '' then o.override
					when
						rr.failure_reason = 'PLACE_BET' then 'BET_PLACEMENT_FAILURE'
					else
						rr.failure_reason
				end as failure_description,
				o.leg_no,
				o.part_no,
				o.ev_oc_id,
				eo.desc as ev_oc_desc,
				e.ev_id,
				e.desc  as ev_desc
			from
				tBIRReq            rr,
				tBIRBet            b,
				tAcct              a,
				tCustomer          c,
				tBIROBet           o,
				tEv                e,
				tEvOc              eo,
				tBetType           t,
				tCustomerReg       r
				$additional_tables
			where
				rr.status       = 'F'            and
				rr.status       = 'F'            and
				rr.bir_req_id   = b.bir_req_id   and
				rr.acct_id      = a.acct_id      and
				a.cust_id       = c.cust_id      and
				b.bir_bet_id    = o.bir_bet_id   and
				o.ev_oc_id      = eo.ev_oc_id    and
				e.ev_id         = eo.ev_id       and
				r.cust_id       = c.cust_id      and
				t.bet_type      = b.bet_type
				$where_status
				$where

			order by
				2 desc,
				o.leg_no,
				o.part_no
		}]

		ob_log::write CRITICAL {additional_tables:\n $additional_tables\n}
		ob_log::write CRITICAL {where_status:\n $where_status\n}
		ob_log::write CRITICAL {where:\n $where\n}

	# Sql for XGames, ordered by Subscriptions
	} elseif {$query_type == "xgame" && $sort_sub == "Sub"} {

		set sql [subst {
			(select
				s.xgame_sub_id,
				b.xgame_bet_id,
				c.username,
				c.acct_no,
				c.elite,
				b.cr_date,
				b.settled,
				d.sort,
				a.ccy_code,
				c.cust_id,
				b.stake,
				b.winnings,
				b.refund,
				g.comp_no,
				s.num_subs,
				s.picks,
				s.ipaddr,
				NVL(g.results,'-') as results,
				d.name
			from
				tAcct a,
				tCustomer c,
				tCustomerReg r,
				tXGameSub s,
				tXGameBet b,
				tXGame g,
				tXGameDef d
			where
				a.cust_id = c.cust_id and
				r.cust_id = c.cust_id and
				a.acct_id = s.acct_id and
				s.xgame_sub_id = b.xgame_sub_id and
				b.xgame_id = g.xgame_id and
				g.sort = d.sort and
				a.owner    <> 'D'
				$where)
			}]

		if {!$xgame_bet_required} {append sql [subst {
			union
			(select
				s.xgame_sub_id,
				-1 as xgame_bet_id,
				c.username,
				c.acct_no,
				c.elite,
				s.cr_date,
				'-' as settled,
				d.sort,
				a.ccy_code,
				c.cust_id,
				s.stake_per_bet as stake,
				0 as winnings,
				0 as refund,
				g.comp_no,
				s.num_subs,
				s.picks,
				s.ipaddr,
				NVL(g.results,'-') as results,
				d.name
			from
				tAcct a,
				tCustomer c,
				tCustomerReg r,
				tXGameSub s,
				tXGame g,
				tXGameDef d
			where
				a.cust_id = c.cust_id and
				r.cust_id = c.cust_id and
				a.acct_id = s.acct_id and
				s.xgame_id = g.xgame_id and
				g.sort = d.sort and
				s.authorized = 'N' and
				a.owner   <> 'D'
				$where)
			order by
				1 desc, 2 desc
			}]}

	# Sql for XGames, ordered by Bets
	} elseif {$query_type == "xgame" && $sort_sub != "Sub"} {

		set sql [subst {
			select
				s.xgame_sub_id,
				b.xgame_bet_id,
				c.username,
				c.acct_no,
				c.elite,
				b.cr_date,
				b.settled,
				d.sort,
				a.ccy_code,
				c.cust_id,
				b.stake,
				b.winnings,
				b.refund,
				g.comp_no,
				s.num_subs,
				s.picks,
				s.ipaddr,
				NVL(g.results,'-') as results,
				d.num_picks_max,
				d.sort,
				d.name
			from
				tAcct a,
				tCustomer c,
				tCustomerReg r,
				tXGameSub s,
				tXGameBet b,
				tXGame g,
				tXGameDef d
			where
				a.cust_id = c.cust_id and
				r.cust_id = c.cust_id and
				a.acct_id = s.acct_id and
				s.xgame_sub_id = b.xgame_sub_id and
				b.xgame_id = g.xgame_id and
				g.sort = d.sort and
				a.owner    <> 'D'
				$where
			order by
				b.xgame_bet_id desc
			}]
	} elseif {$query_type == "pools"} {
		set sql [subst {
			select
				b.pool_bet_id,
				c.cust_id,
				c.username,
				c.acct_no,
				c.elite,
				a.ccy_code,
				b.ipaddr,
				b.cr_date,
				b.receipt,
				b.ccy_stake,
				b.stake,
				b.status,
				b.settled,
				b.winnings,
				b.refund,
				b.num_lines,
				(b.stake / b.num_lines) unitstake,
				b.bet_type,
				e.desc ev_name,
				t.name meeting_name,
				s.desc seln_name,
				s.result,
				s.ev_oc_id,
				s.ev_id,
				pb.leg_no,
				pb.part_no,
				p.pool_id,
				p.pool_type_id,
				p.rec_dividend,
				p.result_conf pool_conf,
				pt.name as pool_name,
				ps.ccy_code as pool_ccy_code
			from
				tPoolBet b,
				tPBet pb,
				tAcct a,
				tCustomer c,
				tEvOc s,
				tEvMkt m,
				tEv e,
				tEvType t,
				tCustomerReg r,
				tPool p,
				tPoolType pt,
				tPoolSource ps
				$additional_tables
			where
				b.pool_bet_id = pb.pool_bet_id and
				b.acct_id = a.acct_id and
				a.cust_id = c.cust_id and
				r.cust_id = c.cust_id and
				pb.ev_oc_id = s.ev_oc_id and
				s.ev_mkt_id = m.ev_mkt_id and
				s.ev_id = e.ev_id and
				t.ev_type_id = e.ev_type_id and
				pb.pool_id = p.pool_id and
				p.pool_type_id = pt.pool_type_id and
				p.pool_source_id = pt.pool_source_id and
				pt.pool_source_id = ps.pool_source_id and
				a.owner    <> 'D'
				$where
			order by 1 desc
		}]
	}


	ob_log::write ERROR "*****executing query : \n**************"
	ob_log::write ERROR "$sql"

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set rows [db_get_nrows $res]

	# If sports bet: play
	if {$query_type == "sports"} {
		if {$rows == 1 && [db_get_col $res 0 bet_type] != "MAN"} {
			go_bet_receipt bet_id [db_get_col $res 0 bet_id]

			db_close $res
			return
		}

		bind_sports_bet_list $res 0 1

		asPlayFile -nocache bet_list.html

		unset BET

	# If BIR failed bet:
	} elseif {$query_type == "birfail"} {

		bind_failed_bir_bet_list $res $query_type

		asPlayFile -nocache bet_list_failed_bir.html

		unset BET

	#If XGames:
	} elseif {$query_type == "xgame"} {
		if {$sort_sub == "Sub"} {

			if {$rows == 0} {
				tpSetVar NumBets 0
				db_close $res
				asPlayFile -nocache xgame_sub_list.html

			} elseif {$rows == 1} {
					go_xgame_sub_query sub_id [db_get_col $res 0 xgame_sub_id]
					db_close $res
					return
			} else {
				set cur_id 0
				set b -1

				array set BET [list]

				set elite 0

				for {set r 0} {$r < $rows} {incr r} {
					set bet_id [db_get_col $res $r xgame_sub_id]
					if {$bet_id != $cur_id} {
						set cur_id $bet_id
						set l 0
						incr b

						set BET($b,num_subs) 0
					}

					incr BET($b,num_subs)

					if {[db_get_col $res $r elite] == "Y"} {
						incr elite
					}

					if {$l == 0} {
						set BET($b,xgame_sub_id) $bet_id
						set BET($b,bet_type)  [db_get_col $res $r sort]
						set BET($b,stake)     [db_get_col $res $r stake]
						set BET($b,ccy)       [db_get_col $res $r ccy_code]
						set BET($b,picks)     [db_get_col $res $r picks]
						set BET($b,cust_id)   [db_get_col $res $r cust_id]
						set BET($b,cust_name) [db_get_col $res $r username]
						set BET($b,acct_no)   [db_get_col $res $r acct_no]
						set BET($b,game_name) [db_get_col $res $r name]
						set BET($b,elite)     [db_get_col $res $r elite]
					}

					# if xgame_bet_id = -1 then sub not authorized
					set xgame_bet_id [db_get_col $res $r xgame_bet_id]
					if {$xgame_bet_id == -1} {
						set valid_bet 	0
						set no_bet "-"
						set no_bet_id ""
						set BET($b,$l,xgame_bet_id) $no_bet_id
						set BET($b,$l,comp_no)   	$no_bet
						set BET($b,$l,bet_time)  	$no_bet
						set BET($b,$l,results)   	$no_bet
						set BET($b,$l,settled)   	$no_bet
						set BET($b,$l,winnings)  	$no_bet
						set BET($b,$l,refund)    	$no_bet

					} else {
						set valid_bet 	1
						set BET($b,$l,xgame_bet_id) $xgame_bet_id
						set BET($b,$l,comp_no)   [db_get_col $res $r comp_no]
						set BET($b,$l,bet_time)  [db_get_col $res $r cr_date]
						set BET($b,$l,results)   [db_get_col $res $r results]
						set BET($b,$l,settled)   [db_get_col $res $r settled]
						set BET($b,$l,winnings)  [db_get_col $res $r winnings]
						set BET($b,$l,refund)    [db_get_col $res $r refund]
					}
					incr l
				}

				db_close $res

				tpSetVar NumBets [expr {$b+1}]
				tpBindVar CustId      BET cust_id       bet_idx
				tpBindVar Elite       BET elite         bet_idx
				tpBindVar CustName    BET cust_name     bet_idx
				tpBindVar AcctNo      BET acct_no       bet_idx
				tpBindVar SubId       BET xgame_sub_id  bet_idx
				tpBindVar BetType     BET bet_type      bet_idx
				tpBindVar BetCCY      BET ccy           bet_idx
				tpBindVar BetPicks	  BET picks		    bet_idx
				tpBindVar BetStake    BET stake         bet_idx
				tpBindVar GameName    BET game_name     bet_idx

				if {$valid_bet==1} {
					tpBindVar BetID  	  BET xgame_bet_id   bet_idx seln_idx
					tpBindVar CompNo	  BET comp_no	     bet_idx seln_idx
					tpBindVar BetTime     BET bet_time       bet_idx seln_idx
					tpBindVar Result      BET results        bet_idx seln_idx
					tpBindVar Price       BET price          bet_idx seln_idx
					tpBindVar BetSettled  BET settled        bet_idx seln_idx
					tpBindVar Winnings    BET winnings	     bet_idx seln_idx
					tpBindVar Refund	  BET refund  	     bet_idx seln_idx

				} else {
					tpBindVar BetID  	  BET xgame_bet_id   bet_idx
					tpBindVar CompNo	  BET comp_no	     bet_idx
					tpBindVar BetTime     BET bet_time       bet_idx
					tpBindVar Result      BET results        bet_idx
					tpBindVar Price       BET price          bet_idx
					tpBindVar BetSettled  BET settled        bet_idx
					tpBindVar Winnings    BET winnings	     bet_idx
					tpBindVar Refund	  BET refund  	     bet_idx
				}

				tpSetVar IS_ELITE $elite

				asPlayFile -nocache xgame_sub_list.html
				unset BET
			}

		# Ordered by bets
		} else {

			if {$rows == 0} {
				tpSetVar NumBets 0
				db_close $res
				asPlayFile -nocache xgame_bet_list.html

			} elseif {$rows == 1} {
				go_xgame_receipt bet_id [db_get_col $res 0 xgame_bet_id]
				db_close $res
				return
			} else {

				set b 0
				array set BET [list]
				set elite 0
				for {set r 0} {$r < $rows} {incr r} {
					set bet_id [db_get_col $res $r xgame_sub_id]
					set BET($b,xgame_sub_id) $bet_id
					set BET($b,bet_type)     [db_get_col $res $r sort]
					set BET($b,stake)        [db_get_col $res $r stake]
					set BET($b,ccy)          [db_get_col $res $r ccy_code]
					set BET($b,picks)        [db_get_col $res $r picks]
					set BET($b,cust_id)      [db_get_col $res $r cust_id]
					set BET($b,cust_name)    [db_get_col $res $r username]
					set BET($b,elite)        [db_get_col $res $r elite]
					set BET($b,acct_no)      [db_get_col $res $r acct_no]
					set BET($b,xgame_bet_id) [db_get_col $res $r xgame_bet_id]
					set BET($b,comp_no)      [db_get_col $res $r comp_no]
					set BET($b,bet_time)     [db_get_col $res $r cr_date]
					set BET($b,results)      [db_get_col $res $r results]
					set BET($b,settled)      [db_get_col $res $r settled]
					set BET($b,winnings)     [db_get_col $res $r winnings]
					set BET($b,refund)       [db_get_col $res $r refund]
					set BET($b,game_name)    [db_get_col $res $r name]
					incr b
					if {[db_get_col $res $r elite] == "Y"} {
						incr elite
					}
				}

				db_close $res

				tpSetVar NumBets [expr {$b+1}]
				tpBindVar CustId      BET cust_id       bet_idx
				tpBindVar Elite       BET elite         bet_idx
				tpBindVar CustName    BET cust_name     bet_idx
				tpBindVar AcctNo      BET acct_no       bet_idx
				tpBindVar SubId       BET xgame_sub_id  bet_idx
				tpBindVar BetType     BET bet_type      bet_idx
				tpBindVar BetCCY      BET ccy           bet_idx
				tpBindVar BetPicks    BET picks		bet_idx
				tpBindVar BetStake    BET stake         bet_idx
				tpBindVar BetID       BET xgame_bet_id  bet_idx
				tpBindVar CompNo      BET comp_no	bet_idx
				tpBindVar BetTime     BET bet_time      bet_idx
				tpBindVar Result      BET results       bet_idx
				tpBindVar Price       BET price         bet_idx
				tpBindVar BetSettled  BET settled       bet_idx
				tpBindVar Winnings    BET winnings	bet_idx
				tpBindVar Refund      BET refund  	bet_idx
				tpBindVar GameName    BET game_name     bet_idx

				tpSetVar IS_ELITE $elite

				asPlayFile -nocache xgame_bet_list.html
				unset BET
			}
		}

	} elseif {$query_type == "pools"} {
		if {$rows == 1} {
			go_pools_receipt bet_id [db_get_col $res 0 pool_bet_id]

			db_close $res
			return
		}

		bind_pools_bet_list $res

		asPlayFile -nocache pool_bet_list.html

		unset POOL_BET



	}