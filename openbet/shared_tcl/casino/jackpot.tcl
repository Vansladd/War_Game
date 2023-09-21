# $Id: jackpot.tcl,v 1.1 2011/10/04 12:25:51 xbourgui Exp $
# (C) 2006 Orbis Technology Ltd. All rights reserved.
#
# Some useful casino-jackpot-related procs
#
# Configuration:
#
# Synopsis:
#     package require casino_jackpot ?4.5?
#
# Procedures:
#    ob_casino::jackpot::init    one time initialisation
#

package provide casino_jackpot 4.5


# Dependencies
#
package require util_log     4.5
package require util_db      4.5
package require util_control 4.5

package require tdom


# Variables
#
namespace eval ob_casino::jackpot {

	variable INIT

	set INIT 0
}


#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
# Get the package configuration and prepare queries.
#
proc ob_casino::jackpot::init args {

	variable CFG
	variable INIT

	# already initialised
	if {$INIT} {
		return
	}

	# initialise dependencies
	ob_log::init
	ob_db::init
	ob_control::init

	ob_log::write DEBUG {CASINO JACKPOT: init}

	# get configuration
	array set OPT [list \
		qry_cache_time     60 \
		refresh_cache_time 10 \
		refresh_rate       10]
	
	foreach c [array names OPT] {
		set CFG($c) [OT_CfgGet "JACKPOT_[string toupper $c]" $OPT($c)]
	}

	_prepare_qrys

	set INIT 1
}

proc ob_casino::jackpot::get_jackpots { arr args } {

	variable CFG
	
	ob_log::write INFO {CASINO JACKPOT -> in get_jackpots}

	upvar 1 $arr jackpot_arr

	switch [llength $args] {

		0       { set ccy_code [ob_control::get default_ccy] }
		1       { set ccy_code [lindex $args 0] }
		default {
			error "wrong # args:\
				   should be ob_casino::jackpot::get_jackpots arr ?ccy_code?"
		}

	}

	if {[catch {
		set rs [ob_db::exec_qry ob_casino::jackpot::get_jackpot_list $ccy_code]
	} msg]} {
		ob_log::write ERROR {CASINO JACKPOT: Unable to retrieve jackpots: $msg}
		return
	}
	
	set num_jackpots  [db_get_nrows $rs]

	set total_jackpot 0.00
	set total_rate    0.00
	
	for { set i 0 } { $i < $num_jackpots } { incr i } {
		set jackpot_arr($i,progressive_id) [db_get_col $rs $i progressive_id]
		set jackpot_arr($i,name)           [db_get_col $rs $i name]
		set jackpot_arr($i,blurb)          [db_get_col $rs $i blurb]
		set jackpot_arr($i,ccy_code)       [db_get_col $rs $i ccy_code]

		if {[catch {
			set rs2 [ob_db::exec_qry ob_casino::jackpot::get_curr_jackpot \
									 $jackpot_arr($i,progressive_id) \
									 $jackpot_arr($i,ccy_code)]
		} msg]} {
			ob_log::write ERROR \
				{CASINO JACKPOT: Unable to retrieve current jackpot: $msg}
			return
		}
		set real_jackpot [format %.2f [db_get_coln $rs2 0]]
		ob_db::rs_close $rs2

		if {[catch {
			set rs2 [ob_db::exec_qry ob_casino::jackpot::get_jackpot_rate \
									 $jackpot_arr($i,progressive_id)]
		} msg]} {
			ob_log::write ERROR \
				{CASINO JACKPOT: Unable to retrieve jackpot rate: $msg}
			return
		}
		set rate [db_get_coln $rs2 0]
		ob_db::rs_close $rs2

		if {[catch {
			set rs2 [ob_db::exec_qry ob_casino::jackpot::get_games \
									 $jackpot_arr($i,progressive_id)]
		} msg]} {
			ob_log::write ERROR {CASINO JACKPOT: Unable to retrieve games: $msg}
			return
		}
		set jackpot_arr($i,num_games) [db_get_nrows $rs2]
		for { set j 0 } { $j < $jackpot_arr($i,num_games) } { incr j } {
			set jackpot_arr($i,$j,game_id)      [db_get_col $rs2 $j cg_id]
			set jackpot_arr($i,$j,game_version) [db_get_col $rs2 $j version]
		}
		ob_db::rs_close $rs2

		set jackpot_arr($i,rate)    \
			[format %.2f [expr { $rate / $CFG(refresh_rate) }]]

		set jackpot_arr($i,jackpot) \
			[format %.2f [expr { $real_jackpot - $rate }]]
			
		set total_jackpot [expr {$total_jackpot + $jackpot_arr($i,jackpot)}]
		set total_rate    [expr {$total_rate    + $rate}]
	}
	
	ob_db::rs_close $rs

	# Handle the Jackpot Total now
	set jackpot_arr($i,progressive_id) -1
	set jackpot_arr($i,name)           Total
	set jackpot_arr($i,blurb)          Total
	set jackpot_arr($i,ccy_code)       $ccy_code
	set jackpot_arr($i,jackpot)        [format %.2f $total_jackpot]
	set jackpot_arr($i,rate)           [format %.2f [expr {
		$total_rate / $CFG(refresh_rate)
	}]]

	set jackpot_arr(count) $num_jackpots
}

# Private procedure to prepare the package queries
#
proc ob_casino::jackpot::_prepare_qrys args {

	variable CFG

	ob_db::store_qry ob_casino::jackpot::get_jackpot_list {
		select
			p.progressive_id,
			p.name,
			p.blurb,
			c.ccy_code
		from
			tCGProgressive p,
			tCGProgCcy c
		where
			p.status         = 'A'
		and p.progressive_id = c.progressive_id
		and c.ccy_code       = ?
		order by p.progressive_id;
	} $CFG(refresh_rate)

	ob_db::store_qry ob_casino::jackpot::get_curr_jackpot {
		
		execute procedure pCGGetJackpot (
			p_progressive_id = ?,
			p_ccy_code       = ?,
			p_payout_rate    = '100.00'
		);
	} $CFG(refresh_rate)
	
	ob_db::store_qry ob_casino::jackpot::get_games {

		select
			cg_id,
			version
		from tCGGameProgressive
		where progressive_id = ?

	} $CFG(refresh_cache_time)

	ob_db::store_qry ob_casino::jackpot::get_jackpot_rate [subst {
		select
			nvl (sum (ps.fixed_stake), 0)
		from
			tCGProgHist    ph,
			tCGProgSummary ps,
			tCGGameSummary gs
		where
			ps.cg_game_id     = gs.cg_game_id
		and ps.prog_hist_id   = ph.prog_hist_id
		and ph.progressive_id = ?
		and gs.started between current - $CFG(refresh_rate) units second
						   and current

	}] $CFG(refresh_cache_time)

}
