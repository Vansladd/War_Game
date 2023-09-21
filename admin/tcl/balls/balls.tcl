# ==============================================================
# $Id: balls.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::BALLS {

asSetAct ADMIN::BALLS::GoBallsQuery   		[namespace code go_balls_query]
asSetAct ADMIN::BALLS::GoBallsSetup		[namespace code go_balls_setup]
asSetAct ADMIN::BALLS::DoBallsQuery   		[namespace code do_balls_query]
asSetAct ADMIN::BALLS::GoBallsSubDesc 		[namespace code do_balls_sub_desc]
asSetAct ADMIN::BALLS::DoBallsConfig            [namespace code do_balls_config]
asSetAct ADMIN::BALLS::UpdBallsConfig		[namespace code upd_balls_config]
asSetAct ADMIN::BALLS::DoBallsGameConfig        [namespace code do_balls_game_config]
asSetAct ADMIN::BALLS::UpdBallsGameConfig	[namespace code upd_balls_game_config]

#
# ----------------------------------------------------------------------------
# Generate iBalls bet query selection data, namely the different iballs games
# available and relay the iBalls query html page
# ----------------------------------------------------------------------------
#
proc go_balls_query args {
	
	global DB BET
	
	# Make sure the user has the right to view balls bets
	if {![op_allowed ViewBallsBets]} {
		err_bind "You don't have permission to view Balls bets."
		tpSetVar HasPerm 0
		asPlayFile -nocache balls/balls_query.html
		return
	}	
	
	tpSetVar HasPerm 1

	# Get the game type id and names for the iBalls from the DB

	set sql {
		select
			s.type_id as game_type_id,
			s.desc as game_name
		from
			tBallsSubType s
		order by
			type_id
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	
	inf_close_stmt $stmt	

	set rows [db_get_nrows $res]
	
	set b 0
	array set BET [list]
	for {set r 0} {$r < $rows} {incr r} {

		set BET($b,game_type)    	[db_get_col $res $r game_type_id]
		set BET($b,game_name)		[db_get_col $res $r game_name]
		
		incr b
		
	}
	
	tpSetVar game_type_rows $rows

	tpBindVar GameType		BET 	game_type    	game_type_idx
	tpBindVar GameName		BET		game_name		game_type_idx
	
	db_close $res
		
	# Play the iballs query web page
	
	asPlayFile -nocache balls/balls_query.html
	
	unset BET
}

#
# ----------------------------------------------------------------------------
# Generate iBalls set-up data, namely the different iballs games
# available so they can be configured
# ----------------------------------------------------------------------------
#
proc go_balls_setup args {
	
	global DB BET
	
	# Make sure the user has the right to view balls bets
	if {![op_allowed ConfigBalls]} {
		err_bind "You don't have permission to configure the Balls game set-up."
		tpSetVar HasPerm 0
		asPlayFile -nocache balls/balls_setup.html
		return
	}	
	
	tpSetVar HasPerm 1

	# Get the game type id and names for the iBalls from the DB

	set sql {
		select
			s.type_id as game_type_id,
			s.desc as game_name
		from
			tBallsSubType s
		order by
			type_id
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	
	inf_close_stmt $stmt	

	set rows [db_get_nrows $res]
	
	set b 0
	array set BET [list]
	for {set r 0} {$r < $rows} {incr r} {

		set BET($b,game_type)    	[db_get_col $res $r game_type_id]
		set BET($b,game_name)		[db_get_col $res $r game_name]
		
		incr b
	}
	
	tpSetVar game_type_rows $rows

	tpBindVar GameType		BET 	game_type    	game_type_idx
	tpBindVar GameName		BET     game_name	game_type_idx
	
	db_close $res
		
	# Play the iballs setup web page
	
	asPlayFile -nocache balls/balls_setup.html
	
	unset BET
}

#
# ----------------------------------------------------------------------------
# Carry out the iBalls search using the supplied search parameters and relay
# the iBalls subscriptions results page
# ----------------------------------------------------------------------------
#
proc do_balls_query args {

	global DB BET
	
	# Make sure the user has the right to view balls bets
	if {![op_allowed ViewBallsBets]} {
		err_bind "You don't have permission to view Balls bets."
		tpSetVar HasPerm 0
		asPlayFile -nocache balls/balls_bet_list.html
		return
	}	
	
	tpSetVar HasPerm 1	
	
	# SQL where and from clause
	set where [list]
	set from [list]

	# Build up our SQL search query using the supplied search parameters

	#
	# Customer fields
	#
	if {[string length [set name [reqGetArg Customer]]] > 0} {
		if {[reqGetArg UpperCust] == "Y"} {
			lappend where "[upper_q c.username] like [upper_q '${name}%']"
		} else {
			lappend where "c.username like \"${name}%\""
		}
	}
	if {[string length [set fname [reqGetArg FName]]] > 0} {
		lappend where "[upper_q r.fname] = [upper_q \'$fname\']"
	}
	if {[string length [set lname [reqGetArg LName]]] > 0} {
		lappend where [get_indexed_sql_query $lname lname]
	}
	if {[string length [set email [reqGetArg Email]]] > 0} {
		lappend where [get_indexed_sql_query "%$email" email]
	}
	if {[string length [set acctno [reqGetArg AcctNo]]] > 0} {
		lappend where "upper(c.acct_no) = upper('$acctno')"
	}
	
	#
	# Draw number
	#
	set drawNo [reqGetArg DrawNo]
	
	if {([string length $drawNo] > 0)} {
	
		lappend where "($drawNo between s.firstdrw_id and s.lastdrw_id)"
	
		# There should be a table (tBallsDrwSub) linking subscriptions with draws but we should test first
		# to make sure it exists before using it. If it does not exist then we might just
		# have to put up with a slow query
		if { [catch {set stmt [inf_prep_sql $DB {select count(*) from tBallsDrwSub}]} msg] } {
			
			# Do nothing but avoid error message popping up
			tpSetVar IsError 0
			
		} else {
					
			# Unprepare statement and use table
			inf_close_stmt $stmt
			
			lappend from "tBallsDrwSub d"
			
			lappend where "d.drw_id = $drawNo"
			lappend where {d.sub_id = s.sub_id}
		}
			
	}

	#
	# Bet date fields:
	#
	set bd1 [reqGetArg BetDate1]
	set bd2 [reqGetArg BetDate2]

	if {([string length $bd1] > 0) || ([string length $bd2] > 0)} {
			lappend where [mk_between_clause s.cr_date date $bd1 $bd2]
	}

	#
    # Bet date fixed periods
    #
	set bdperiod [reqGetArg BetPlacedFrom]
	if {[string length $bdperiod] > 0 && $bdperiod > 0} {

		set cur_time_seconds [clock seconds]
		set cur_time_formatted [clock format $cur_time_seconds -format {%Y-%m-%d %H:%M:%S}]
		set yesterday_time_seconds [expr $cur_time_seconds - 60*60*24]
		set three_days_ago_seconds [expr $cur_time_seconds - 3*60*60*24]
		set one_week_ago_seconds [expr $cur_time_seconds - 7*60*60*24]
		set curr_month [clock format $cur_time_seconds -format {%Y-%m-01 00:00:00}]

		switch -exact -- $bdperiod {
			1 {lappend where [mk_between_clause s.cr_date date [clock format $cur_time_seconds -format {%Y-%m-%d 00:00:00}] [clock format $cur_time_seconds -format {%Y-%m-%d 23:59:59}]]}
			2 {lappend where [mk_between_clause s.cr_date date [clock format $yesterday_time_seconds -format {%Y-%m-%d 00:00:00}] [clock format $yesterday_time_seconds -format {%Y-%m-%d 23:59:59}]]}
			3 {lappend where [mk_between_clause s.cr_date date [clock format $three_days_ago_seconds -format {%Y-%m-%d 00:00:00}] $cur_time_formatted]}
			4 {lappend where [mk_between_clause s.cr_date date [clock format $one_week_ago_seconds -format {%Y-%m-%d 00:00:00}] $cur_time_formatted]}
			5 {lappend where [mk_between_clause s.cr_date date $curr_month $cur_time_formatted]}
		}
	}

	#
	# Bet stake
	#
	set s1 [reqGetArg Stake1]
	set s2 [reqGetArg Stake2]

	if {([string length $s1] > 0) || ([string length $s2] > 0)} {
		lappend where [mk_between_clause s.stake number $s1 $s2]
	}

	#
	# Winnings
	#
	set w1 [reqGetArg Wins1]
	set w2 [reqGetArg Wins2]

	if {([string length $w1] > 0) || ([string length $w2] > 0)} {
		lappend where [mk_between_clause s.returns number $w1 $w2]
	}

	#
	# Game type e.g. Pick N (1)
	#
	# (i.e. 'is a' (0) and 'is not a' (1) and 'N/A' ())
	#
	if {([string length [set op [reqGetArg GameTypeOp]]] > 0) &&
	    ([set nt [reqGetNumArgs GameType]] > 0)} {

		for {set n 0} {$n < $nt} {incr n} {
			lappend bt [reqGetNthArg GameType $n]
		}
		if {$op == "0"} {
			set qop "not in"
		} else {
			set qop "in"
		}

		lappend where "s.type_id $qop ('[join $bt ',']')"
	}

	# Either 'A' (active) or 'C' (completed)
	set betStatus [reqGetArg BetStatus]

	#
	# Bet Status (pools bets)
	#
	if {[string length [set betStatus [reqGetArg BetStatus]]] > 0} {
	
		# If active check for row in tBallsActSub
		if {($betStatus == "A")} {
		
			lappend where "exists (select v.sub_id from tballsactsub v where v.sub_id = s.sub_id)"
			
		} else {
		
			# Check that row does not exist in tBallsActSub
			lappend where "not exists (select v.sub_id from tballsactsub v where v.sub_id = s.sub_id)"
			
		}
	}

	#
	# Don't run a query with no search criteria...
	#
	if {![llength $where]} {
		# Nothing selected
		err_bind "Please enter some search criteria"
		go_balls_query
		return
	}
	
	# Put our 'and' joiners in to the where and from clause
	set where [concat "and " [join $where " and "]]
	
	if {$from != {}} {
		set from [concat ", " [join $from " , "]]
	}
		
	set sql [subst {	
		select
			c.cust_id,
			c.username,
			c.acct_no,
			a.ccy_code,
			s.sub_id,
			s.cr_date,
			s.stake,
			s.returns,
			s.ndrw,
			s.firstdrw_id,
			s.lastdrw_id,
			s.seln,
			s.oddsnum,
			s.oddsden,
			case when (i.sub_id is null) then 'Y' else 'N' end as completed,	
			t.desc as game_desc
		from
			tBallsSub s,
			tBallsSubType t,
			tAcct a,
			tCustomer c,
			tCustomerReg r,
			outer tBallsActSub i
			$from
		where
			s.type_id = t.type_id and
			s.sub_id = i.sub_id and
			s.acct_id = a.acct_id and
			a.cust_id = c.cust_id and
			c.cust_id = r.cust_id
			$where
		order by 
			c.cust_id,
			s.sub_id
		}]
								
	# Run the database search query
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set rows [db_get_nrows $res]
	
	# If we got no rows then return HTML page
	if {$rows == 0} {
		tpSetVar NumBets 0
		db_close $res
		asPlayFile -nocache balls/balls_bet_list.html
		return
	} 
		
	# Set the bet details

	set b 0
	array set BET [list]
	for {set r 0} {$r < $rows} {incr r} {

		set BET($b,sub_id)    		[db_get_col $res $r sub_id]
		set BET($b,username)  		[db_get_col $res $r username]
		set BET($b,cust_id)   		[db_get_col $res $r cust_id]
		set BET($b,acct_no)     	[db_get_col $res $r acct_no]
		set BET($b,bet_time)       	[db_get_col $res $r cr_date]

		# Display the draws placed for
		set numDraws [db_get_col $res $r ndrw]
		if {$numDraws == 1} {
			set BET($b,draws)		"(1) [db_get_col $res $r firstdrw_id]"
		} else {
			set BET($b,draws)		"($numDraws) [db_get_col $res $r firstdrw_id]-[db_get_col $res $r lastdrw_id]"
		}

		set BET($b,ccy)				[db_get_col $res $r ccy_code]			
		set BET($b,stake)   		[db_get_col $res $r stake]
		set BET($b,odds)			"[db_get_col $res $r oddsnum]/[db_get_col $res $r oddsden]"
		set BET($b,winnings)  		[db_get_col $res $r returns]
		set BET($b,game)   			[db_get_col $res $r game_desc]
		set BET($b,seln)   			[db_get_col $res $r seln]
		set BET($b,completed)		[db_get_col $res $r completed]
		
		# Active bets are highlighted so get this information
		if {$BET($b,completed) == "Y"} {
			set ACTIVE($b) 0
		} else {
			set ACTIVE($b) 1
		}

		incr b
	}

	db_close $res

	tpSetVar NumBets [expr {$b+1}]

	tpBindVar SubId       		BET sub_id    		bet_idx
	tpBindVar Username    		BET username 		bet_idx
	tpBindVar CustId      		BET cust_id   		bet_idx
	tpBindVar AcctNo      		BET acct_no	    	bet_idx
	tpBindVar BetTime     		BET bet_time  		bet_idx
	tpBindVar Draws				BET draws			bet_idx
	tpBindVar Ccy	    		BET ccy     		bet_idx
	tpBindVar Stake  	  		BET stake			bet_idx
	tpBindVar Odds		  		BET odds			bet_idx
	tpBindVar Winnings     		BET winnings	  	bet_idx
	tpBindVar Game      		BET game	   		bet_idx
	tpBindVar Seln       		BET seln     		bet_idx
	tpBindVar Completed			BET completed		bet_idx

	asPlayFile -nocache balls/balls_bet_list.html

	# Make sure we unset the global array
	unset BET
}

#
# ----------------------------------------------------------------------------
# Get the description page for a subscription. The draws for this subscription will also
# be displayed
# ----------------------------------------------------------------------------
#
proc do_balls_sub_desc args {

	global DB DRAW
	
	# Make sure the user has the right to view balls bets
	if {![op_allowed ViewBallsBets]} {
		err_bind "You don't have permission to view Balls bets."
		tpSetVar HasPerm 0
		asPlayFile -nocache balls/balls_sub.html
		return
	}	
	
	tpSetVar HasPerm 1		
	
	# Get the subscription
	set subId [reqGetArg SubId]
	
	# Get the bet details
	set sql {
		select
			c.cust_id,
			c.username,
			c.acct_no,
			a.ccy_code,
			s.sub_id,
			s.cr_date,
			s.stake,
			s.returns,
			s.ndrw,
			s.firstdrw_id,
			s.lastdrw_id,
			s.seln,
			s.oddsnum,
			s.oddsden,
			case when (i.sub_id is null) then 'Y' else 'N' end as completed,	
			t.desc as game_desc
		from
			tBallsSub s,
			tBallsSubType t,
			tAcct a,
			tCustomer c,
			tCustomerReg r,
			outer tBallsActSub i
		where
			s.type_id = t.type_id and
			s.sub_id = i.sub_id and
			s.acct_id = a.acct_id and
			a.cust_id = c.cust_id and
			c.cust_id = r.cust_id and
			s.sub_id = ?
	}

	# Get the details for this subscription
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $subId]

	inf_close_stmt $stmt
	
	# Make sure we got a subscription
	if {[db_get_nrows $res] == 0} {
		db_close $res
		err_bind "No subscription found with id: $subId"
		tpSetVar HasPerm 0
		asPlayFile -nocache balls/balls_sub.html
		return
	} 

	# Bind the subscription details

	tpBindString SubId      	[db_get_col $res sub_id]
	tpBindString CustId			[db_get_col $res cust_id]
	tpBindString Username		[db_get_col $res username]
	tpBindString AcctNo			[db_get_col $res acct_no]
	tpBindString CcyCode		[db_get_col $res ccy_code]
	tpBindString BetDate		[db_get_col $res cr_date]
	tpBindString Stake			[db_get_col $res stake]
	tpBindString Winnings		[db_get_col $res returns]

	# Display the draws placed for
	set numDraws [db_get_col $res ndrw]
	if {$numDraws == 1} {
		tpBindString Draws		"(1) [db_get_col $res firstdrw_id]"
	} else {
		tpBindString Draws		"($numDraws) [db_get_col $res firstdrw_id]-[db_get_col $res lastdrw_id]"
	}

	tpBindString Seln			[db_get_col $res seln]
	tpBindString Odds			"[db_get_col $res oddsnum]/[db_get_col $res oddsden]"
	tpBindString Game			[db_get_col $res game_desc]
	tpBindString Completed		[db_get_col $res completed]

	# Close this result set
	db_close $res

	# Get the details for the draws that have occured
	set sql {	
		select
			d.drw_id,
			d.cr_date as draw_date,
			d.ball1,
			d.ball2,
			d.ball3,
			d.ball4,
			d.ball5,
			d.ball6,
			d.status,
			nvl(p.payout,0.00) as payout,
			p.cr_date as payout_date,
			case when (p.payout is null) then 'N' else 'Y' end as win	
		from
			tballssub s,
			tballsdrw d,
			outer tballspayout p
		where
			d.drw_id between s.firstdrw_id and s.lastdrw_id and
			p.sub_id = s.sub_id and
			p.drw_id = d.drw_id and
			s.sub_id = ?
		order by
			d.drw_id
	}

	# Run the database search query
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $subId]

	inf_close_stmt $stmt

	set rows [db_get_nrows $res]

	# If we got no rows then return HTML page since no draw details to show
	if {$rows == 0} {
		tpSetVar NumDrawsMade 0
		db_close $res
		asPlayFile -nocache balls/balls_sub.html
		return
	} 

	# Set the draw details

	set d 0
	array set DRAW [list]
	for {set r 0} {$r < $rows} {incr r} {

		set DRAW($d,draw_id)    	[db_get_col $res $r drw_id]
		set DRAW($d,draw_date)  	[db_get_col $res $r draw_date]
		set DRAW($d,ball1)  		[db_get_col $res $r ball1]
		set DRAW($d,ball2)  		[db_get_col $res $r ball2]
		set DRAW($d,ball3)  		[db_get_col $res $r ball3]
		set DRAW($d,ball4)  		[db_get_col $res $r ball4]
		set DRAW($d,ball5)  		[db_get_col $res $r ball5]
		set DRAW($d,ball6)  		[db_get_col $res $r ball6]

		# Set the draw status
		switch [db_get_col $res $r status] {
			P	{
				set DRAW($d,status) "Pending"
			}
			C	{
				set DRAW($d,status) "Settled"
			}
			default
				set DRAW($d,status) "Unknown"
		}

		# Only populate payout on winning payout
		set DRAW($d,win)	[db_get_col $res $r win]

		if {$DRAW($d,win) == "Y"} {
			set DRAW($d,payout)			[db_get_col $res $r payout]
			set DRAW($d,payout_date) 	[db_get_col $res $r payout_date]
		}

		incr d
	}

	db_close $res

	tpSetVar NumDrawsMade [expr {$d+1}]

	tpBindVar DrawId       		DRAW draw_id   		draw_idx
	tpBindVar DrawDate			DRAW draw_date 		draw_idx
	tpBindVar Ball1      		DRAW ball1   		draw_idx
	tpBindVar Ball2      		DRAW ball2	    	draw_idx
	tpBindVar Ball3     		DRAW ball3  		draw_idx
	tpBindVar Ball4     		DRAW ball4    		draw_idx
	tpBindVar Ball5				DRAW ball5			draw_idx
	tpBindVar Ball6	    		DRAW ball6     		draw_idx
	tpBindVar Win  	  			DRAW win			draw_idx
	tpBindVar Payout	  		DRAW payout			draw_idx
	tpBindVar PayoutDate   		DRAW payout_date  	draw_idx

	asPlayFile -nocache balls/balls_sub.html

	# Make sure we unset the global array
	unset DRAW
}

#
# ----------------------------------------------------------------------------
# Relay the HTML page to allow an admin user to configure the iBalls application.
# The current iBalls configuration will be required.
# ----------------------------------------------------------------------------
#
proc do_balls_config args {
	
	global DB
	
	# Make sure the user has the right to view balls bets
	if {![op_allowed ConfigBalls]} {
		err_bind "You don't have permission to configure the Balls set-up."
		tpSetVar HasPerm 0
		asPlayFile -nocache balls/balls_config.html
		return
	}	
	
	tpSetVar HasPerm 1
	
	# Get the current Balls configuration
	
	set sql {
		select
			maxnactsubs
		from
			tballsconfig
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	
	inf_close_stmt $stmt	

	# If we go not message then display error
	if {[db_get_nrows $res] == 0} {
		err_bind "Unable to retrieve Balls configuration"
		tpSetVar HasPerm 0
		asPlayFile -nocache balls/balls_config.html
		return
	}
		
	tpBindString MaxNumActiveSubs [db_get_col $res maxnactsubs]
		
	db_close $res
		
	asPlayFile -nocache balls/balls_config.html
}

#
# ----------------------------------------------------------------------------
# Relay the HTML page to allow an admin user to configure a subscription game.
# The current game configuration will be required.
# ----------------------------------------------------------------------------
#
proc do_balls_game_config args {
	
	global DB
	
	# Make sure the user has the right to view balls bets
	if {![op_allowed ConfigBalls]} {
		err_bind "You don't have permission to configure the Balls game set-up."
		tpSetVar HasPerm 0
		asPlayFile -nocache balls/balls_game.html
		return
	}	
	
	tpSetVar HasPerm 1
	
	# Get the subscription game type number
	set subTypeId [reqGetArg SubTypeId]
	
	# Make sure we got a value
	if {($subTypeId == "")} {
		err_bind "Unable to get request argument 'SubTypeId'"
		tpSetVar HasPerm 0
		asPlayFile -nocache balls/balls_game.html
		return
	}

	# Get the name and message for this error

	set sql {
		select
			s.desc,
			s.oddsnum,
			s.oddsden,
			s.minstake,
			s.maxstake,
			s.status
		from
			tBallsSubType s
		where
			s.type_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $subTypeId]
	
	inf_close_stmt $stmt	

	# If we go not message then display error
	if {[db_get_nrows $res] == 0} {
		err_bind "Unable to find details for subcription type (id): $subTypeId"
		tpSetVar HasPerm 0
		asPlayFile -nocache balls/balls_game.html
		return
	}
	
	tpBindString SubTypeId $subTypeId
	tpBindString Desc [db_get_col $res desc]
	tpBindString OddsNum [db_get_col $res oddsnum]
	tpBindString OddsDen [db_get_col $res oddsden]
	tpBindString MinStake [db_get_col $res minstake]
	tpBindString MaxStake [db_get_col $res maxstake]

	if {[db_get_col $res status] == "A"} {
		tpSetVar ActiveStatus 1
	} else {
		tpSetVar ActiveStatus 0
	}
	
	db_close $res
		
	asPlayFile -nocache balls/balls_game.html	
}

#
# ---------------------------------------------------------------------------
# Update the balls configuration values in the database. The 
# values inputted will be validated and any errors returned
# ---------------------------------------------------------------------------
#
proc upd_balls_config args {

	global DB
	
	# Make sure the user has the right to configure the balls app
	if {![op_allowed ConfigBalls]} {
		err_bind "You don't have permission to configure the Balls set-up."
		tpSetVar HasPerm 0
		asPlayFile -nocache balls/balls_config.html
		return
	}	
	
	tpSetVar HasPerm 1
	
	# Get the max number of draws per sub figure
	set MaxNumActiveSubs [reqGetArg MaxNumActiveSubs]
	
	# Make sure we got a value
	if {($MaxNumActiveSubs == "")} {
		err_bind "Unable to get request argument 'MaxNumActiveSubs'"
		do_balls_config
		return
	}
	
	# Make sure the figure is valid
	if {![is_valid_pos_int $MaxNumActiveSubs]} {
		err_bind "Invalid Max Num Active Subs: $MaxNumActiveSubs"
		do_balls_config
		return
	}
			
	# Update the config in the database
	set sql {
		update
			tBallsConfig
		set
			maxnactsubs = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	inf_exec_stmt $stmt $MaxNumActiveSubs
	
	inf_close_stmt $stmt	

	# Go back to setup
	go_balls_setup
}

#
# ---------------------------------------------------------------------------
# Update the subscription game configuration values in the database. The 
# values inputted will be validated and any errors returned
# ---------------------------------------------------------------------------
#
proc upd_balls_game_config args {

	global DB
	
	# Make sure the user has the right to view balls bets
	if {![op_allowed ConfigBalls]} {
		err_bind "You don't have permission to configure the Balls game set-up."
		tpSetVar HasPerm 0
		asPlayFile -nocache balls/balls_game.html
		return
	}	
	
	tpSetVar HasPerm 1
	
	# Get the subscription game type number
	set subTypeId [reqGetArg SubTypeId]
	
	# Make sure we got a value
	if {($subTypeId == "")} {
		err_bind "Unable to get request argument 'SubTypeId'"
		tpSetVar HasPerm 0
		asPlayFile -nocache balls/balls_game.html
		return
	}

	# Get the min stake and make sure it is valid
	set minStake [reqGetArg MinStake]
	
	if {![is_valid_stake $minStake]} {
		err_bind "Invalid minimum stake: $minStake"
		do_balls_game_config
		return
	}
	
	# Get the max stake and make sure it is valid
	set maxStake [reqGetArg MaxStake]
	
	if {![is_valid_stake $maxStake]} {
		err_bind "Invalid maximum stake: $maxStake"
		do_balls_game_config
		return
	}
	
	# Make sure the max stake is >= min stake
	if {$minStake > $maxStake} {
		err_bind "Min stake ($minStake) must not be greater than Max stake ($maxStake)"
		do_balls_game_config
		return
	}
	
	# Get the odds and make sure they are valid
	set oddsNum [reqGetArg OddsNum]
	set oddsDen [reqGetArg OddsDen]
	
	if {!([is_valid_pos_int $oddsNum] && [is_valid_pos_int $oddsDen])} {
		err_bind "Invalid odds: $oddsNum / $oddsDen"
		do_balls_game_config
		return
	}	
	
	# Get the status and make sure it is valid
	set status [reqGetArg Status]
	
	if {($status != "A") && ($status != "S")} {
		err_bind "Invalid status: $status"
		do_balls_game_config
		return
	}
	
	# Update the config in the database

	set sql {
		update
			tBallsSubType
		set
			status = ?,
			minstake = ?,
			maxstake = ?,
			oddsnum = ?,
			oddsden = ?
		where
			type_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	inf_exec_stmt $stmt $status $minStake $maxStake $oddsNum $oddsDen $subTypeId
	
	inf_close_stmt $stmt	

	# Go back to setup
	go_balls_setup
}

#
# Return true if the supplied text is a valid positive integer
#
# num - The integer number
#
proc is_valid_pos_int { num } {

	# Set out the regular expression for the integer format
	set REX_NUM {^([0-9]+)$}
	
	# Check that the inputted odd is in the required format
	if {![regexp $REX_NUM $num]} {
		return 0
	}
	
	# Make sure int is positive
	if {$num <= 0} {
		return 0
	}
	
	# Must be OK
	return 1
}

#
# Returns true if the text supplied is a valid monetary cost
# Negative costs are deemed to be invalid.
#
# Stake - The stake to validate
#
proc is_valid_stake { Stake } {

	# Check for blank or . stake
	if {($Stake == {}) || ($Stake == {.})} {
		return 0
	}

	# Set out the regular expression for the integer format	
	set REX_NUM {^([0-9]*[.]?([0-9]|[0-9][0-9])?)$}
		
	# Check that the inputted integer is in the required format
	if {![regexp $REX_NUM $Stake]} {
		return 0
    }
    
    # Make sure Stake is positive
    if {[expr $Stake + 0] <= 0} {
    	return 0
    }
    
    # Must be OK
    return 1
    
}		

}