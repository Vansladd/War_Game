# $Id: winners.tcl,v 1.1 2011/10/04 12:25:51 xbourgui Exp $
# (C) 2006 Orbis Technology Ltd. All rights reserved.
#
# Retrieves information on winners from the db
#
# Configuration:
#
# Synopsis:
#	package require casino_winners ?4.5?
#
# Procedures:
#	ob_casino::winners::init                  One time initialisation
#	ob_casino::winners::max_win               Finds the single biggest win in the last x hours
#	ob_casino::winners::biggest_winners       Retrieve a list of the x biggest winning 
#	                                          customers over hours days
#	ob_casino::winners::biggest_jack_winners  Retrieve a list of the x
#	                                          customers who have won the most from 
#	                                          jackpots over hours days
#	ob_casino::winners::total_winnings        Retrieves the total paid out in the last p_hours
#	ob_casino::winners::recent_winners        Retrieves the recent winners in the db
#	ob_casino::winners::most_recent_wins      Retrieves the most recent wins in the db
#	ob_casino::winners::most_recent_jack_wins Retrieves the most recent
#	                                          jackpot wins in the db
#

package provide casino_winners 4.5

# Dependencies
#
package require util_log 4.5
package require util_db  4.5
package require tdom

# Variables
#
namespace eval ob_casino::winners {
	variable INIT
	set INIT 0
}

#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
# Get the package configuration and prepare queries.
#
proc ob_casino::winners::init {{qry_cache_time 600} args} {
	
	variable INIT
	# already initialised
	if {$INIT} {
		return
	}

	# initialise dependencies
	ob_log::init
	ob_db::init

	ob_log::write DEBUG {CASINO WINNERS: init}

	ob_casino::winners::_prepare_qrys $qry_cache_time

	set INIT 1
}

##
# ob_casino::winners::max_win
#
# SYNOPSIS
#
#	[max_win]
#
# SCOPE
#
#	public
#
# PARAMS
#
#	hours  - Number of hours that the win must be within since current time
#	arr    - The WINNERS array
#	?type? - G (Game) or S (Summary)
#	?lang? - The translation language.
#	?only_initials? - Only show the customers initials
#
# RETURN
#
#	none
#
# DESCRIPTION
#
#	Finds the single biggest win in the last <hours> hours and binds the results.
#	Type G means this will be the biggest winner in each game and type S
#	means this will be the biggest winner over all games.
#
##
proc ob_casino::winners::max_win {   hours
									 arr
								   { type S }
								   { lang en }
								   { only_initials 0 } } {
	
	upvar 1 $arr WINNERS

	if { $type eq "G" } {
		set qry ::ob_casino::winners::get_max_win_games
		}
	} else {
		set qry ::ob_casino::winners::get_max_win_summary
	}
	
	if {[catch {
		set rs [ob_db::exec_qry $qry $hours]
	} msg]} {
		ob::log::write ERROR {error while executing exec_qry\
								$qry $hours: $msg}
		return
	}

	_retrieve_and_bind max_win_${type}_ WINNERS rs $type $lang $only_initials

}

##
# ob_casino::winners::biggest_winners
#
# SYNOPSIS
#
#	[biggest_winners]
#
# SCOPE
#
#	public
#
# PARAMS
#
#	hours     - Number of hours that the win must be within since current time
#	arr       - The winners array
#	num_custs - The maximum number of customers to be returned
#	?type?    - G (Game) or S (Summary)
#	?lang?    - The translation language.
#	?only_initials? - Only show the customers initials
#
# RETURN
#
#	none
#
# DESCRIPTION
#
#	Retrieves and binds an array of the <num_custs> biggest winning customers 
#	over the last <hours> hours. Type G shows this for each game and type S 
#	shows this over all games.
#
##
proc ob_casino::winners::biggest_winners {   hours
											 arr
											 num_custs
										   { type S }
										   { lang en }
										   { only_initials 0 } } {
	
	upvar 1 $arr WINNERS

	if { $type eq "G" } {
		set qry ::ob_casino::winners::get_biggest_winners_game
	} else {
		set qry ::ob_casino::winners::get_biggest_winners_summary
	}

	if {[catch {
		set rs [ob_db::exec_qry $qry $hours $num_custs]
	} msg]} {
		ob::log::write ERROR {error while executing exec_qry\
								$qry $hours $num_custs: $msg}
		return
	}

	_retrieve_and_bind biggest_winners_${type}_ \
					   WINNERS \
					   rs \
					   $type \
					   $lang \
					   $only_initials
}

##
# ob_casino::winners::biggest_jack_winners
#
# SYNOPSIS
#
#	[biggest_jack_winners]
#
# SCOPE
#
#	public
#
# PARAMS
#
#	days            - Number of days that the win must be within since current time
#	arr	            - The winners array
#	min_win	        - The smallest win amount to be shown
#	num_custs       - The maximum number of customers to be returned
#	?type?          - G (Game) or S (Summary)
#	?lang?          - The translation language.
#	?only_initials? - Only show the customers initials
#
# RETURN
#
#	none
#
# DESCRIPTION
#
#	Retrieves and binds a list of the <num_custs> customers who have won the 
#	most from jackpot (with a minimum winnings of <min_win>) over the last 
#	<days> days. Type G shows the biggest jackpot winners per game and type 
#	S show the biggest jackpot winners over all games.
#
##
proc ob_casino::winners::biggest_jack_winners {	  days
												  arr
												  min_win
												  num_custs
												{ type S }
												{ lang en }
												{ only_initials 0 } } {

	
	upvar 1 $arr WINNERS

	if { $type eq "G" } {
		set qry ::ob_casino::winners::get_biggest_jack_winners_game
	} else {
		set qry ::ob_casino::winners::get_biggest_jack_winners_summary
	}

	if {[catch {
		set rs [ob_db::exec_qry $qry $days $min_win $num_custs]
	} msg]} {
		ob::log::write ERROR {error while executing exec_qry\
								$qry $days $min_win $num_custs: $msg}
		return
	}

	_retrieve_and_bind biggest_jack_winners_${type}_ \
					   WINNERS \
					   rs \
					   $type \
					   $lang \
					   $only_initials
}

##
# ob_casino::winners::total_winnings
#
# SYNOPSIS
#
#	[total_winnings]
#
# SCOPE
#
#	public
#
# PARAMS
#
#	hours  - Number of hours that the win must be within since current time
#	arr	   - Winners array
#	?type? - G (Game) or S (Summary)
#	?lang? - The translation language.
#
# RETURN
#
#	none
#
# DESCRIPTION
#
#	Retrieves and binds the total paid out in the last <hours> hours. Type G
#	gets the total won for each game and type S gets the total won over all
#	games.
#
##

proc ob_casino::winners::total_winnings {
	hours 
	arr 
	{type S} 
	{lang en} } {
	
	upvar 1 $arr WINNERS

	if { $type eq "G" } {
		set qry ::ob_casino::winners::get_total_winnings_game
	} else {
		set qry ::ob_casino::winners::get_total_winnings_summary
	}

	if {[catch {
		set rs [ob_db::exec_qry $qry $hours]
	} msg]} {
		ob::log::write ERROR {error while executing exec_qry\
								$qry $hours: $msg}
		return
	}

	set prefix "total_winnings_${type}_"
	set nrows [db_get_nrows $rs]	
	for {set i 0} {$i < $nrows} {incr i} {
			
		set WINNERS($i,${prefix}winnings) [db_get_coln $rs $i 0]
		set WINNERS($i,${prefix}ccy)	  [ob_util::get_html_ccy_symbol	[db_get_coln $rs $i 1]]
	
		if {$type=="G"} {	
			set WINNERS($i,${prefix}gname)  [db_get_coln $rs $i 2]
			set WINNERS($i,${prefix}gtitle) [ob_xl::XL $lang \
				|CASINO_GAME_TITLE_[string toupper [db_get_coln $rs $i 2]]|]
		} 
	}
	
	tpSetVar "${prefix}numWinners" $nrows
	
	if { $type eq "G" } {
		tpBindVar ${prefix}GName  WINNERS ${prefix}gname  winner_idx
		tpBindVar ${prefix}GTitle WINNERS ${prefix}gtitle winner_idx
	}
	
	tpBindVar ${prefix}Winnings WINNERS ${prefix}winnings winner_idx
	tpBindVar ${prefix}Ccy      WINNERS ${prefix}ccy      winner_idx

}

##
# ob_casino::winners::recent_winners
#
# SYNOPSIS
#
#	[recent_winners]
#
# SCOPE
#
#	public
#
# PARAMS
#
#	hours     - Number of hours that the win must be within since current time
#	arr       - Winners array
#	min_win   - The smallest win amount to be shown
#	num_custs - The maximum number of customers to be returned
#	?type?    - G (Game) or S (Summary)
#	?lang?    - The translation language.
#	?only_initials? - Only show the customers initials
#
# RETURN
#
#	none
#
# DESCRIPTION
#
#	Retrieves and binds the <num_custs> most recent winners over the last
#	<hours> hours, winnings greater than <min_win>. Type G gets winners over
#	each game and type S gets winners over all games.
#
##
proc ob_casino::winners::recent_winners {   mins
											arr
											min_win
											num_custs
										  { type S }
										  { lang en }
										  { only_initials 0 } } {
	
	upvar 1 $arr WINNERS

	if { $type eq "G" } {
		set qry ::ob_casino::winners::get_recent_winners_game
	} else {
		set qry ::ob_casino::winners::get_recent_winners_summary
	}

	if {[catch {
		set rs [ob_db::exec_qry $qry $mins $min_win $num_custs]
	} msg]} {
		ob::log::write ERROR {error while executing exec_qry\
								$qry $mins $min_win $num_custs: $msg}
		return
	}

	_retrieve_and_bind recent_winners_${type}_ \
					   WINNERS \
					   rs \
					   $type \
					   $lang \
					   $only_initials

}

##
# ob_casino::winners::most_recent_jack_wins
#
# SYNOPSIS
#
#	[most_recent_jack_wins]
#
# SCOPE
#
#	public
#
# PARAMS
#
#	days     - Number of days that the win must be within since current time
#	arr      - Winners array
#	min_win	 - The smallest win amount to be shown
#	num_wins - The maximum number of customers to be returned
#	?type?   - G (Game) or S (Summary)
#	?lang?   - The translation language.
#	?only_initials? - Only show the customers initials
#
# RETURN
#
#	none
#
# DESCRIPTION
#
#	Retrieves and binds the <num_wins> most recent jackpots wins over the last
#	<days> days that were over <min_win>. Type G shows the most recent jackpot
#	wins over each game and type S shows the most recent jackpot wins in any
#	game.
#
##
proc ob_casino::winners::most_recent_jack_wins {   days
												   arr
												   min_win
												   num_wins
												 { type S }
												 { lang en }
												 { only_initials 0 } } {
	
	upvar 1 $arr WINNERS

	if { $type eq "G" } {
		set qry ::ob_casino::winners::get_most_recent_jack_wins_game
	} else {
		set qry ::ob_casino::winners::get_most_recent_jack_wins_summary
	}

	if {[catch {
		set rs [ob_db::exec_qry $qry $days $min_win $num_wins]
	} msg]} {
		ob::log::write ERROR {error while executing exec_qry\
								$qry $days $min_win $num_wins: $msg}
		return
	}

	#
	# The type var is set to G because we always want to show game information.
	#
	_retrieve_and_bind most_recent_jack_wins_${type}_ \
					   WINNERS \
					   rs \
					   G \
					   $lang \
					   $only_initials \
					   1
}

##
# ob_casino::winners::most_recent_wins
#
# SYNOPSIS
#
#	[most_recent_wins]
#
# SCOPE
#
#	public
#
# PARAMS
#
#	hours    - Number of hours that the win must be within since current time
#	arr      - Winners array
#	min_win	 - The smallest win amount to be shown
#	num_wins - The maximum number of customers to be returned
#	?type?   - G (Game) or S (Summary)
#	?lang?   - The translation language.
#	?only_initials? - Only show the customers initials
#
# RETURN
#
#	none
#
# DESCRIPTION
#
#	Retrieves and binds the <num_wins> most recent wins over the last <hours>
#	hours which were over <min_win>. Type G shows recent wins for each game and
#	type S shows recent wins for any game.
#
##
proc ob_casino::winners::most_recent_wins {   mins
											  arr
											  min_win
											  num_wins
											{ type S }
											{ lang en }
											{ only_initials 0 } } {

	
	upvar 1 $arr WINNERS

	if { $type eq "G" } {
		set qry ::ob_casino::winners::get_most_recent_wins_game
	} else {
		set qry ::ob_casino::winners::get_most_recent_wins_summary
	}

	if {[catch {
		set rs [ob_db::exec_qry $qry $mins $min_win $num_wins]
	} msg]} {
		ob::log::write ERROR {error while executing exec_qry\
								$qry $mins $min_win $num_wins: $msg}
		return
	}

	#
	# The type var is set to G because we always want to show game information.
	#
	_retrieve_and_bind most_recent_wins_${type}_ \
					   WINNERS \
					   rs \
					   G \
					   $lang \
					   $only_initials \
					   1
}

# Private Proc to Retrieve relevent data from the db query and bind
#
proc ob_casino::winners::_retrieve_and_bind {	prefix
												arr
												results
												type
												lang
												only_initials
											  { time_since_col 0 } } {

	upvar 1 $arr WINNERS
	upvar 1 $results rs

	set colnames [list fname lname uname cust_id country ccy winnings]
	if {$time_since_col} {
		set colnames [list tsince fname lname uname cust_id country ccy winnings]
	}
	if {$type == "G"} {
		lappend colnames "gname"
	}
	
	set nrows [db_get_nrows $rs]
	for {set i 0} {$i < $nrows} {incr i} {
		set n 0
		foreach col $colnames {
			set WINNERS($i,${prefix}${col}) [db_get_coln $rs $i $n]
			incr n			
		}
		set WINNERS($i,${prefix}ccy) [ob_util::get_html_ccy_symbol \
			$WINNERS($i,${prefix}ccy)]
		if {$only_initials} {
			set WINNERS($i,${prefix}fname) [string toupper \
				[string index $WINNERS($i,${prefix}fname) 0]]
			set WINNERS($i,${prefix}lname) [string toupper \
				[string index $WINNERS($i,${prefix}lname) 0]]
		}
		if {$type == "G"} {
			set WINNERS($i,${prefix}gtitle) [ob_xl::XL $lang \
				"|CASINO_GAME_TITLE_[string toupper $WINNERS($i,${prefix}gname)]|"]
		}
	}
	
	tpSetVar "${prefix}numWinners" $nrows
	
	if {$type == "G"} {
		tpBindVar ${prefix}GName  WINNERS ${prefix}gname  winner_idx
		tpBindVar ${prefix}GTitle WINNERS ${prefix}gtitle winner_idx
	}

	if {$time_since_col} {
		tpBindVar ${prefix}TSince WINNERS ${prefix}tsince winner_idx
	}

	tpBindVar ${prefix}FName    WINNERS ${prefix}fname    winner_idx
	tpBindVar ${prefix}LName    WINNERS ${prefix}lname    winner_idx
	tpBindVar ${prefix}UserName WINNERS ${prefix}uname    winner_idx
	tpBindVar ${prefix}cust_id  WINNERS ${prefix}cust_id  winner_idx
	tpBindVar ${prefix}Country  WINNERS ${prefix}country  winner_idx
	tpBindVar ${prefix}Ccy	    WINNERS ${prefix}ccy      winner_idx
	tpBindVar ${prefix}Winnings WINNERS ${prefix}winnings winner_idx
}

# Private procedure to prepare the package queries
#
proc ob_casino::winners::_prepare_qrys {qry_cache_time}  {

	ob_log::write DEBUG {Preparing queries for ob_casino::winners}
	
	## Finds the single biggest win in the last p_hours
	ob_db::store_qry ::ob_casino::winners::get_max_win_summary {
		execute procedure pCGGetMaxWinS(
			p_hours = ?
		)
	} $qry_cache_time

	## Gets the biggest winner for each game in the last p_hours
	ob_db::store_qry ::ob_casino::winners::get_max_win_games {
		execute procedure pCGGetMaxWinG(
			p_hours = ?
		)
	} $qry_cache_time

	## Retrieve a list of the x biggest winning customers over y hours
	ob_db::store_qry ::ob_casino::winners::get_biggest_winners_summary {
		execute procedure pCGGetBigWinnersS(
			p_hours = ?,
			p_max_customer = ?
		)
	} $qry_cache_time

	## Retrieve a list of the x biggest winning customers over y hours
	ob_db::store_qry ::ob_casino::winners::get_biggest_winners_game {
		execute procedure pCGGetBigWinnersG(
			p_hours = ?,
			p_max_customer = ?
		)
	} $qry_cache_time

	## Retrieve a list of the x customers who have one the most from jackpots
	## over y hours
	ob_db::store_qry ::ob_casino::winners::get_biggest_jack_winners_summary {
		execute procedure pCGGetBigJackWinnersS(
			p_days = ?,
			p_min_win = ?,
			p_max_customer = ?
		)
	} $qry_cache_time

	## Retrieve a list of the x customers who have one the most from jackpots
	## over y hours by game
	ob_db::store_qry ::ob_casino::winners::get_biggest_jack_winners_game {
		execute procedure pCGGetBigJackWinnersG(
			p_days = ?,
			p_min_win = ?,
			p_max_customer = ?
		)
	} $qry_cache_time

	## Retrieves the total paid out in the last p_hours
	ob_db::store_qry ::ob_casino::winners::get_total_winnings_summary {
		execute procedure pCGGetTotalWonS(
			p_hours = ?
		)
	} $qry_cache_time

	## Retrieves the total paid out in the last p_hours game by game
	ob_db::store_qry ::ob_casino::winners::get_total_winnings_game {
		execute procedure pCGGetTotalWonG(
			p_hours = ?
		)
	} $qry_cache_time

	## finds num_cust customers winning more than min_win in the last p_hours
	ob_db::store_qry ::ob_casino::winners::get_recent_winners_summary {
		execute procedure pCGGetRecWinnersS(
			p_mins = ?,
			p_num_cust = ?,
			p_min_win = ?
		)
	} $qry_cache_time

	## finds num_cust distinct customers winning more than min_win in the last p_hours
	ob_db::store_qry ::ob_casino::winners::get_distinct_recent_winners_summary {
		execute procedure pCGGetRecWinnersS(
			p_mins = ?,
			p_num_cust = ?,
			p_min_win = ?,
			p_distinct = 1
		)
	} $qry_cache_time

	## finds num_cust customers winning more than min_win in the last p_hours by game
	ob_db::store_qry ::ob_casino::winners::get_recent_winners_game {
		execute procedure pCGGetRecWinnersG(
			p_mins = ?,
			p_min_win = ?,
			p_num_cust = ?
		)
	} $qry_cache_time

	## finds p_num_wins most recent wins more than min_win in the last p_hours
	ob_db::store_qry ::ob_casino::winners::get_most_recent_wins_summary {
		execute procedure pCGGetMRecWinsS(
			p_mins = ?,
			p_min_win = ?,
			p_num_wins = ?
		)
	} $qry_cache_time

	## finds p_num_wins most recent wins more than min_win in the 
	## last p_hours by game
	ob_db::store_qry ::ob_casino::winners::get_most_recent_wins_game {
		execute procedure pCGGetMRecWinsG(
			p_mins = ?,
			p_min_win = ?,
			p_num_wins = ?
		)
	} $qry_cache_time

	## finds p_num_wins most recent jackpot winns more than min_win in the last p_hours
	ob_db::store_qry ::ob_casino::winners::get_most_recent_jack_wins_summary {
		execute procedure pCGGetMRecJackS(
			p_days = ?,
			p_min_win = ?,
			p_num_wins = ?
		)
	} $qry_cache_time

	## finds p_num_wins most recent jackpot wins more than min_win in the 
	## last p_hours by game
	ob_db::store_qry ::ob_casino::winners::get_most_recent_jack_wins_game {
		execute procedure pCGGetMRecJackG(
			p_days = ?,
			p_min_win = ?,
			p_num_wins = ?
		)
	} $qry_cache_time


}

#-------------------------------------------------------------------------------
# vim:noet:ts=4:sts=4:sw=4:tw=80:ft=tcl:ff=unix:
#-------------------------------------------------------------------------------
